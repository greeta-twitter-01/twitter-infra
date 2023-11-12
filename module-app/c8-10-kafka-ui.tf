resource "kubernetes_deployment_v1" "kafka_ui" {
  depends_on = [helm_release.bitnami_kafka_schema_registry]
  metadata {
    name = "kafka-ui"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kafka-ui"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka-ui"
        }
      }

      spec {
        container {
          name  = "kafka-ui"
          image = "provectuslabs/kafka-ui:latest"
          
          port {
            container_port = 8080
          }

          env {
            name  = "KAFKA_CLUSTERS_0_NAME"
            value = "local"
          }

          env {
            name  = "KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS"
            value = "bitnami-kafka:9092"
          }

          env {
            name  = "KAFKA_CLUSTERS_0_SCHEMAREGISTRY"
            value = "http://schema-registry:8081"
          }

          env {
            name  = "DYNAMIC_CONFIG_ENABLED"
            value = "true"
          }

        }
      }
    }
  }
}

resource "kubernetes_service_v1" "kafka_ui" {
  metadata {
    name = "kafka-ui"
  }
  spec {
    selector = {
      app = "kafka-ui"
    }
    port {
      port = 8080
    }
  }
}