# Canonical Kubernetes Logging and Monitoring docs

bootstrap cloud and run juju deploy cdk-logging-monitoring.yaml

*Note that Prometheus or Prometheus2 charms can be used. RBAC must be disabled before deploying the monitoring solution.*

once deployed, run the scripts to enable the customisations:

```
# run customisation scripts
chmod 700 scripts/monitoring-config.sh
./monitoring-config.sh
```

*Note: The script may have an error about Prometheus or Prometheus2, just ignore this.*

It is also possible to use conjure-up to add the logging and monitoring tools. 
