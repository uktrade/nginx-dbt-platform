FROM public.ecr.aws/nginx/nginx:1.23.3

RUN apt-get update && \
    apt-get install -y --no-install-recommends dumb-init  && \
    apt-get install -y --no-install-recommends openssl && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

# forward request and error logs to docker log collector.
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

COPY datadog.sh /datadog.sh
RUN chmod +x datadog.sh && /datadog.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/entrypoint.sh"]
