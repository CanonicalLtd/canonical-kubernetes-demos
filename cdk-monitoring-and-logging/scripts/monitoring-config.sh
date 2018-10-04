#!/bin/bash
#

# set -e

#################### Monitoring #####################################
# gather vars (stripping quotes) for later config and result message
grafana_public_ip=$(juju status  grafana --format yaml | grep public-address | sed -e 's/public-address://g' | sed -e 's/ //g')
grafana_port=$(juju config grafana port | sed -e 's/"//g')
kube_client_pass=$(juju run --unit kubernetes-master/0 'cat /home/ubuntu/config' | grep 'password:' | sed -e 's/ *//g' -e 's/password://')
kube_ingress_ip=$(juju run --unit kubeapi-load-balancer/0 'network-get website --format yaml --ingress-address' | head -1)

# configure k8s prometheus scraper
juju config prometheus scrape-jobs="$(sed -e s/K8S_PASSWORD/$kube_client_pass/g -e s/K8S_API_ENDPOINT/$kube_ingress_ip/g ./prometheus-scrape-k8s.yaml)"

# setup grafana dashboards
juju run-action --wait grafana/0 import-dashboard dashboard="$(base64 ./grafana-telegraf.json)"
juju run-action --wait grafana/0 import-dashboard dashboard="$(base64 ./grafana-k8s.json)"


#################### Report summary ##################################
echo ""
echo ""
echo "The Grafana UI is available at: http://$grafana_public_ip:$grafana_port."
echo
echo "Username is admin."
echo
echo "Retrieve the grafana password with: juju run-action --wait grafana/0 get-admin-password"
echo ""

