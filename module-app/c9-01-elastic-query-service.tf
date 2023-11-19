resource "kubernetes_config_map_v1" "elastic_query" {
  metadata {
    name      = "elastic-query"
    labels = {
      app = "elastic-query"
    }
  }

  data = {
    "application.yml" = file("${path.module}/app-conf/elastic-query.yml")
  }
}

resource "kubernetes_deployment_v1" "elastic_query_deployment" {
  depends_on = [kubernetes_deployment_v1.twitter_postgres_deployment]
  metadata {
    name = "elastic-query"
    labels = {
      app = "elastic-query"
    }
  }
 
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "elastic-query"
      }
    }
    template {
      metadata {
        labels = {
          app = "elastic-query"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/actuator/prometheus"
          "prometheus.io/port"   = "8080"
        }        
      }
      spec {
        service_account_name = "spring-cloud-kubernetes"      
        
        container {
          image = "ghcr.io/greeta-twitter-01/elastic-query-service:ff6a98d4aebec327681899695953504df71b2fa9"
          name  = "elastic-query"
          image_pull_policy = "Always"
          port {
            container_port = 8080
          }  
          port {
            container_port = 8001
          } 

          env {
            name  = "SERVER_PORT"
            value = "8080"
          }

          env {
            name  = "SPRING_CLOUD_BOOTSTRAP_ENABLED"
            value = "true"
          }

          env {
            name  = "SPRING_CLOUD_KUBERNETES_SECRETS_ENABLEAPI"
            value = "true"
          }

          env {
            name  = "JAVA_TOOL_OPTIONS"
            value = "-javaagent:/workspace/BOOT-INF/lib/opentelemetry-javaagent-1.17.0.jar"
          }

          env {
            name  = "OTEL_SERVICE_NAME"
            value = "elastic-query"
          }

          env {
            name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value = "http://tempo.observability-stack.svc.cluster.local:4317"
          }

          env {
            name  = "OTEL_METRICS_EXPORTER"
            value = "none"
          }

          env {
            name  = "BPL_JVM_THREAD_COUNT"
            value = "50"
          }

          env {
            name  = "BPL_DEBUG_ENABLED"
            value = "true"
          }

          env {
            name  = "BPL_DEBUG_PORT"
            value = "8001"
          }       
          

          # resources {
          #   requests = {
          #     memory = "756Mi"
          #     cpu    = "0.1"
          #   }
          #   limits = {
          #     memory = "756Mi"
          #     cpu    = "2"
          #   }
          # }          

          lifecycle {
            pre_stop {
              exec {
                command = ["sh", "-c", "sleep 5"]
              }
            }
          }

          # liveness_probe {
          #   http_get {
          #     path = "/actuator/health/liveness"
          #     port = 8080
          #   }
          #   initial_delay_seconds = 120
          #   period_seconds        = 15
          # }

          # readiness_probe {
          #   http_get {
          #     path = "/actuator/health/readiness"
          #     port = 8080
          #   }
          #   initial_delay_seconds = 20
          #   period_seconds        = 15
          # }  
         
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v1" "elastic_query_hpa" {
  metadata {
    name = "elastic-query-hpa"
  }
  spec {
    max_replicas = 2
    min_replicas = 1
    scale_target_ref {
      api_version = "apps/v1"
      kind = "Deployment"
      name = kubernetes_deployment_v1.elastic_query_deployment.metadata[0].name 
    }
    target_cpu_utilization_percentage = 70
  }
}

resource "kubernetes_service_v1" "elastic_query_service" {
  depends_on = [kubernetes_deployment_v1.elastic_query_deployment]
  metadata {
    name = "elastic-query"
    labels = {
      app = "elastic-query"
      spring-boot = "true"
    }
  }
  spec {
    selector = {
      app = "elastic-query"
    }
    port {
      name = "prod"
      port = 8080
    }
    port {
      name = "debug"
      port = 8001
    }    
  }
}