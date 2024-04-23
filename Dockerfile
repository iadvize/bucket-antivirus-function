FROM --platform=linux/amd64 amazonlinux:2023

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

WORKDIR /tmp
RUN yum update -y
RUN yum install -y cpio python3-pip yum-utils zip unzip less wget
RUN wget https://www.clamav.net/downloads/production/clamav-1.3.1.linux.x86_64.rpm

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3 install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp

RUN yumdownloader glibc libgcc
RUN rpm2cpio glibc*.rpm | cpio -idmv
RUN rpm2cpio libgcc*.rpm | cpio -idmv
RUN rpm2cpio clamav*.rpm | cpio -idmv


# Copy over the binaries and libraries
RUN cp -rf /tmp/usr/local/bin/* /tmp/lib64 /tmp/usr/local/lib64/* /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /usr/local/lib/python3.9/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app