resource "kubernetes_pod_v1" "kafka_client_pod" {
  depends_on = [helm_release.bitnami_kafka]
  metadata {
    name      = "kafka-client"
    namespace = "default"
  }

  spec {
    container {
      name  = "kafka-client"
      image = "confluentinc/cp-enterprise-kafka:6.1.0"

      volume_mount {
        name      = "kafka-client-storage"
        mount_path = "/kafka-client-storage"
      }

      command = ["sh", "-c", "exec tail -f /dev/null"]
    }

    volume {
      name = "kafka-client-storage"
    }
  }
}

resource "null_resource" "copy_script" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${var.cluster_name} && kubectl cp ${path.module}/init-conf/create-topics.sh ${kubernetes_pod_v1.kafka_client_pod.metadata.0.name}:/kafka-client-storage"
  }
  depends_on = [kubernetes_pod_v1.kafka_client_pod]
}

resource "null_resource" "execute_script" {
  provisioner "local-exec" {
    command = "kubectl exec -it ${kubernetes_pod_v1.kafka_client_pod.metadata.0.name} -- /bin/bash -c 'cd ../.. && cd kafka-client-storage && sh create-topics.sh'"
  }
  depends_on = [null_resource.copy_script]
}