# Container image that runs your code
FROM alpine:3.12

RUN apk add --no-cache git openssh-client bash jq curl \
    && echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]