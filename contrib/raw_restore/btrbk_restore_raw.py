#!/usr/bin/env python3

import os
import logging
import subprocess
import argparse


logger = logging.getLogger(__name__)


class TransformProcess:
    def run(self, bfile, options, **kw):
        raise NotImplementedError()

    @classmethod
    def add_parser_options(cls, parser):
        pass


class TransformOpensslDecrypt(TransformProcess):
    @staticmethod
    def run(bfile, options, **kw):
        return subprocess.Popen([
            'openssl', 'enc', '-d', '-' + bfile.info['cipher'], '-K',
            open(options.openssl_keyfile, 'r').read(), '-iv', bfile.info['iv']], **kw)

    @classmethod
    def add_parser_options(cls, parser):
        parser.add_argument('--openssl-keyfile', help="path to private encryption key file")


class TransformDecompress(TransformProcess):
    def __init__(self, program):
        self.p = program
    
    def run(self, bfile, options, **kw):
        return subprocess.Popen([self.p, '-d'], **kw)


class TransformBtrfsReceive(TransformProcess):
    @staticmethod
    def run(bfile, options, **kw):
        return subprocess.Popen(['btrfs', 'receive', options.btrfs_subvol], **kw)


TRANSFORMERS = (
    TransformOpensslDecrypt, TransformDecompress, TransformBtrfsReceive
)


class BtrfsPipeline:
    def __init__(self, bfile):
        self.bfile = bfile
        self.processors = []

    def append(self, transformer):
        self.processors.append(transformer)
    
    def run(self, options):
        processes = []
        with open(self.bfile.data_file, 'rb') as next_input:
            for transformer in self.processors:
                process = transformer.run(
                    self.bfile, options,
                    stdin=next_input, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE)
                next_input = process.stdout
                processes.append(process)
            btrfs_process = TransformBtrfsReceive.run(
                self.bfile, options, stdin=next_input,
                stderr=subprocess.PIPE, stdout=subprocess.DEVNULL)
            processes.append(btrfs_process)
            # warning: the code below is pretty ugly and hacky
            terminated = 0
            while terminated < len(processes):
                for p in processes:
                    if p.returncode is not None:
                        continue
                    msg = None
                    try:
                        p.wait(timeout=1)
                    except subprocess.TimeoutExpired as e:
                        pass
                    except Exception as e:
                        msg = e
                    else:
                        msg = p.stderr.read().decode('utf-8').strip()
                    finally:
                        if p.returncode is not None:
                            terminated += 1
                            if p.returncode != 0:
                                for p_other in processes:
                                    p_other.terminate()
                                    terminated += 1
                                if msg:
                                    logger.error(f"error running {p.args}: {msg}")


class BackupFile:
    def __init__(self, path):
        assert path.endswith('.info')
        self.info_file = path
        self.info = self._parse_info()
        self.uuid = self.info['RECEIVED_UUID']
        self.data_file = os.path.join(os.path.dirname(path), self.info['FILE'])
        self.parent = self.info.get('RECEIVED_PARENT_UUID')
        self.is_restored = False
    
    def _parse_info(self):
        config = {}
        with open(self.info_file, 'r') as fh:
            # skip command option line
            for line in fh.readlines():
                if '=' not in line:
                    continue
                key, val = line.strip().split('=', maxsplit=1)
                config[key] = val
        return config
    
    def get_transformers(self):
        if 'encrypt' in self.info:
            if self.info['encrypt'] == 'gpg':
                raise NotImplementedError('gpg encryption')
            elif self.info['encrypt'] == 'openssl_enc':
                yield TransformOpensslDecrypt()
            else:
                raise Exception(f'unknown encryption type: "{self.info["encrypt"]}"')
        if 'compress' in self.info:
            yield TransformDecompress(self.info['compress'])

    def restore_file(self, options):
        assert self.info.get('TYPE') == 'raw'
        assert not self.info.get('INCOMPLETE')
        logger.info(f"restoring backup {os.path.basename(self.data_file)}")
        pipeline = BtrfsPipeline(self)
        for transformer in self.get_transformers():
            pipeline.append(transformer)
        pipeline.run(options)
        self.is_restored = True


def restore_from_path(backup, options):
    path = os.path.dirname(backup)
    info_files = {}
    backup_file = BackupFile(backup + '.info')
    restored_files = set()
    for entry in os.scandir(path):
        if entry.is_file() and entry.name.endswith('.info'):
            info = BackupFile(entry.path)
            info_files[info.uuid] = info
    restored_files.update(restore_backup(backup_file, info_files, options))
    logger.info(f"finished; restored {len(restored_files)} backup files")


def restore_backup(bfile, parents, options):
    if bfile.is_restored:
        return
    if bfile.parent:
        parent = parents.get(bfile.parent)
        if not parent:
            msg = (f"missing parent {bfile.parent} for"
                   f"'{os.path.basename(bfile.info_file)}'")
            if options.ignore_missing:
                logger.warning(msg)
            else:
                raise Exception(msg)
        else:
            yield from restore_backup(parent, parents, options)
    bfile.restore_file(options)
    yield bfile.uuid


def main():
    parser = argparse.ArgumentParser(description="restore btrbk raw backup")
    parser.add_argument('backup', help="backup file to restore; for incremental"
                        "backups the parent files must be in the same directory")
    parser.add_argument('btrfs_subvol', help="btrfs subvolume to restore snapshots to using btrfs receive")
    parser.add_argument('--ignore-missing', action='store_true', help="do not fail on missing parent snapshots")
    
    for transformer in TRANSFORMERS:
        transformer.add_parser_options(parser)
        
    args = parser.parse_args()
    restore_from_path(args.backup, args)


if __name__ == '__main__':
    logger.setLevel('INFO')
    logging.basicConfig(format='%(asctime)s %(levelname)s - %(message)s')
    main()
