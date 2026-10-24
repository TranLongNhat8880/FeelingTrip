"""Prepare model files during build without loading runtime secrets or .env."""
from fetch_models import download


def prepare():
    download()
    # Fail the build if dependencies or model files cannot be loaded, instead
    # of accepting a deployment that fails on the first identity request.
    from engine import Engine
    Engine()
    print('Identity models ready.', flush=True)


if __name__ == '__main__':
    prepare()
