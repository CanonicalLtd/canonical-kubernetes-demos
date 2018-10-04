#!/bin/bash
#

# set -e

#################### Monitoring #####################################
# gather vars (stripping quotes) for later config and result message
grafana_public_ip=$(juju status  grafana --format yaml | grep public-address | sed -e 's/public-address://g' | sed -e 's/ //g')
grafana_port=$(juju config grafana port | sed -e 's/"//g')
#kube_client_pass=$(juju run --unit kubernetes-master/0 'cat /home/ubuntu/config' | grep 'password:' | sed -e 's/ *//g' -e 's/password://')
kube_client_pass=$(juju run --unit kubernetes-master/0 'cut -d, -f1 /root/cdk/basic_auth.csv')
echo kubeclient pass: $kube_client_pass
kube_ingress_ip=$(juju run --unit kubeapi-load-balancer/0 'network-get website --format yaml --ingress-address' | head -1)

# configure k8s prometheus scraper
juju config prometheus scrape-jobs="$(sed -e s/K8S_PASSWORD/$kube_client_pass/g -e s/K8S_API_ENDPOINT/$kube_ingress_ip/g ./prometheus-scrape-k8s.yaml)"
juju config prometheus2 scrape-jobs="$(sed -e s/K8S_PASSWORD/$kube_client_pass/g -e s/K8S_API_ENDPOINT/$kube_ingress_ip/g ./prometheus-scrape-k8s.yaml)"

# setup grafana dashboards
juju run-action --wait grafana/0 import-dashboard dashboard="$(base64 ./grafana-telegraf.json)"
juju run-action --wait grafana/0 import-dashboard dashboard="$(base64 ./grafana-k8s.json)"



#################### Logging #########################################
proxy_public_ip=$(juju status apache2 --format yaml | grep public-address | sed -e 's/public-address://g' | sed -e 's/ //g')
es_cluster=$(juju config elasticsearch cluster-name | sed -e 's/"//g')
graylog_ingress_ip=$(juju run --unit graylog/0 'network-get elasticsearch --format yaml --ingress-address' | head -1)

# Filebeat treats graylog as a logstash host.
# NB: The graylog charm should support a beats relation so we dont have to
# set this manually. Also 5044 is hard coded in graylog's log_inputs config.
juju config filebeat logstash_hosts="$graylog_ingress_ip:5044"


# Graylog needs a rev proxy and ES cluster name.
juju config apache2 vhost_http_template="$(base64 ./graylog-vhost.tmpl)"
juju config graylog elasticsearch_cluster_name="$es_cluster"


#################### Report summary ##################################
echo ""
echo ""
echo "The Grafana UI is available at: http://$grafana_public_ip:$grafana_port."
echo
echo "Username is admin."
echo
echo "Retrieve the grafana password with: juju run-action --wait grafana/0 get-admin-password"
echo ""
echo "The Graylog UI is accessible at: http://$proxy_public_ip/. "
echo
echo "Retrieve the admin password with: juju run-action --wait graylog/0 show-admin-password"
echo
echo "NOTE: Graylog configuration may still be in progress. It may take up to 5 minutes for "
echo "the web interface to become ready."


