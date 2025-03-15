FROM sigp/lighthouse:v5.2.1

COPY ../../scripts/devnet/l1-lighthouse-bn-entrypoint.sh /entrypoint-bn.sh
COPY ../../scripts/devnet/l1-lighthouse-vc-entrypoint.sh /entrypoint-vc.sh

VOLUME ["/db"]
