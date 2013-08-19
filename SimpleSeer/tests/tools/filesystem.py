import os, shutil


def delete_and_mkdir(path):
    import shutil
    if os.path.isdir(path):
        shutil.rmtree(path)
    os.makedirs(path)