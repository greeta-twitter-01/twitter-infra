resource "kubernetes_deployment_v1" "twitter_elastic" {
  depends_on = [helm_release.bitnami_kafka_schema_registry]
  metadata {
    name = "twitter-elastic"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "twitter-elastic"
      }
    }

    template {
      metadata {
        labels = {
          app = "twitter-elastic"
        }
      }

      spec {
        container {
          name  = "twitter-elastic"
          image = "docker.elastic.co/elasticsearch/elasticsearch:7.17.4"
          
          port {
            container_port = 9200
          }

          env {
            name  = "node.name"
            value = "elastic"
          }

          env {
            name  = "cluster.name"
            value = "es-twitter-cluster"
          }

          env {
            name  = "discovery.seed_hosts"
            value = "elastic"
          }

          env {
            name  = "cluster.initial_master_nodes"
            value = "elastic"
          }

          env {
            name  = "bootstrap.memory_lock"
            value = "true"
          }

          env {
            name  = "ES_JAVA_OPTS"
            value = "-Xms512m -Xmx512m"
          }                    

        }
      }
    }
  }
}

resource "kubernetes_service_v1" "twitter_elastic" {
  metadata {
    name = "twitter-elastic"
  }
  spec {
    selector = {
      app = "twitter-elastic"
    }
    port {
      port = 9200
    }
  }
}