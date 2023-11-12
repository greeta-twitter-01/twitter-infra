resource "kubernetes_config_map_v1" "restaurant" {
  metadata {
    name      = "restaurant"
    labels = {
      app = "restaurant"
    }
  }

  data = {
    "application.yml" = file("${path.module}/app-conf/restaurant.yml")
  }
}

resource "kubernetes_deployment_v1" "restaurant_deployment" {
  depends_on = [kubernetes_deployment_v1.order_postgres_deployment]
  metadata {
    name = "restaurant"
    labels = {
      app = "restaurant"
    }
  }
 
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "restaurant"
      }
    }
    template {
      metadata {
        labels = {
          app = "restaurant"
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
          image = "ghcr.io/greeta-restaurant-01/restaurant-service:f86173d1bb5bcfe5ea3ecc1b91057147c159655c"
          name  = "restaurant"
          image_pull_policy = "Always"
          port {
            container_port = 8080
          }
          port {
            container_port = 8004
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
            value = "restaurant"
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
            name  = "BPL_DEBUG_ENABLED"
            value = "true"
          }

          env {
            name  = "BPL_DEBUG_PORT"
            value = "8004"
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

resource "kubernetes_horizontal_pod_autoscaler_v1" "restaurant_hpa" {
  metadata {
    name = "restaurant-hpa"
  }
  spec {
    max_replicas = 2
    min_replicas = 1
    scale_target_ref {
      api_version = "apps/v1"
      kind = "Deployment"
      name = kubernetes_deployment_v1.restaurant_deployment.metadata[0].name 
    }
    target_cpu_utilization_percentage = 70
  }
}

resource "kubernetes_service_v1" "restaurant_service" {
  depends_on = [kubernetes_deployment_v1.restaurant_deployment]
  metadata {
    name = "restaurant"
    labels = {
      app = "restaurant"
      spring-boot = "true"
    }
  }
  spec {
    selector = {
      app = "restaurant"
    }
    port {
      port = 8080
    }
  }
}