FROM debian:8

MAINTAINER Ivan Alejandro <ivanalejandro0@gmail.com>

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
                    wget python-dev python-pip libssl-dev libffi-dev

RUN pip install tuf[tools] pycrypto

ADD tuf-stuff.sh /
ADD release.py /

WORKDIR /code

ENTRYPOINT ["/tuf-stuff.sh"]
