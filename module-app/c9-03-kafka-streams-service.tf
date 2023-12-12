resource "kubernetes_config_map_v1" "kafka_streams" {
  metadata {
    name      = "kafka-streams"
    labels = {
      app = "kafka-streams"
    }
  }

  data = {
    "application.yml" = file("${path.module}/app-conf/kafka-streams.yml")
  }
}

resource "kubernetes_deployment_v1" "kafka_streams_deployment" {
  depends_on = [kubernetes_deployment_v1.twitter_postgres_deployment]
  metadata {
    name = "kafka-streams"
    labels = {
      app = "kafka-streams"
    }
  }
 
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "kafka-streams"
      }
    }
    template {
      metadata {
        labels = {
          app = "kafka-streams"
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
          image = "ghcr.io/greeta-twitter-01/kafka-streams-service:e997396c9a65733738bbfee25f37235f04660ddc"
          name  = "kafka-streams"
          image_pull_policy = "Always"
          port {
            container_port = 8080
          }
          port {
            container_port = 8003
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
            value = "kafka-streams"
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
            value = "8003"
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

resource "kubernetes_horizontal_pod_autoscaler_v1" "kafka_streams_hpa" {
  metadata {
    name = "kafka-streams-hpa"
  }
  spec {
    max_replicas = 2
    min_replicas = 1
    scale_target_ref {
      api_version = "apps/v1"
      kind = "Deployment"
      name = kubernetes_deployment_v1.kafka_streams_deployment.metadata[0].name 
    }
    target_cpu_utilization_percentage = 70
  }
}

resource "kubernetes_service_v1" "kafka_streams_service" {
  depends_on = [kubernetes_deployment_v1.kafka_streams_deployment]
  metadata {
    name = "kafka-streams"
    labels = {
      app = "kafka-streams"
      spring-boot = "true"
    }
  }
  spec {
    selector = {
      app = "kafka-streams"
    }
    port {
      port = 8080
    }
  }
}