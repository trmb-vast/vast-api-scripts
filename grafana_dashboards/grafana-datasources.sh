#!/bin/sh

. ./grafana-lib.sh


setup() {
  if grafana_has_data_source ${DATASOURCE_NAME}; then
    info "Grafana: Data source ${DATASOURCE_NAME} already exists"
  else
    if grafana_create_data_source ${DATASOURCE_NAME} ${DATASOURCE_TYPE} ${GRAPHITE_URL}; then
      success "Grafana: Data source ${DATASOURCE_NAME} created"
    else
      error "Grafana: Data source ${DATASOURCE_NAME} could not be created"
    fi
  fi
}

DATASOURCE_NAME=prometheus
DATASOURCE_TYPE=prometheus
GRAPHITE_URL=http://localhost:9090/
setup

DATASOURCE_NAME=graphite
DATASOURCE_TYPE=graphite
GRAPHITE_URL=http://localhost/

setup

