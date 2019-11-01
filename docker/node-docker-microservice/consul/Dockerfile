FROM consul:latest
ADD . /consul/config
RUN agent -retry-join -bind=0.0.0.0 >> ~/consul/log/output.log &
EXPOSE 8301
EXPOSE 8301 8301/udp 8302 8302/udp
EXPOSE 8500 8600 8600/udp