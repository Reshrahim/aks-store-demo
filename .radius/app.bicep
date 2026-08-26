extension radius

param environment string

@secure()
param rabbitMqPassword string

@secure()
param registryPassword string

@secure()
param registryUsername string

resource storeApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'aks-store-demo'
  properties: {
    environment: environment
  }
}

resource mongoDb 'Radius.Data/mongoDatabases@2025-08-01-preview' = {
  name: 'mongo'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/makeline-service/mongodb.go#L127'
    database: 'orderdb'
  }
}

resource redisCache 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis'
  properties: {
    environment: environment
    application: storeApp.id
    size: 'S'
  }
}

resource rabbitmqSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'rabbitmq-credentials'
  properties: {
    environment: environment
    application: storeApp.id
    data: {
      password: {
        value: rabbitMqPassword
      }
    }
  }
}

resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: storeApp.id
    data: {
      password: {
        value: registryPassword
      }
      username: {
        value: registryUsername
      }
    }
  }
}

resource rabbitMq 'Radius.Messaging/rabbitMQ@2025-08-01-preview' = {
  name: 'rabbitmq'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/order-service/plugins/messagequeue.js#L22'
    queue: 'orders'
    username: 'username'
    password: rabbitmqSecret.id
  }
}

resource makelineImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'makeline-service-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/makeline-service/Dockerfile'
    tag: '867dc76'
    build: {
      source: 'git::https://github.com/Reshrahim/aks-store-demo.git//src/makeline-service?ref=867dc76c5c365c30bc8aef3ff570d7aa0c3fa522'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource orderImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'order-service-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/order-service/Dockerfile'
    tag: '867dc76'
    build: {
      source: 'git::https://github.com/Reshrahim/aks-store-demo.git//src/order-service?ref=867dc76c5c365c30bc8aef3ff570d7aa0c3fa522'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource productImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'product-service-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/product-service/Dockerfile'
    tag: '867dc76'
    build: {
      source: 'git::https://github.com/Reshrahim/aks-store-demo.git//src/product-service?ref=867dc76c5c365c30bc8aef3ff570d7aa0c3fa522'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource storeAdminImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'store-admin-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-admin/Dockerfile'
    tag: '867dc76'
    build: {
      source: 'git::https://github.com/Reshrahim/aks-store-demo.git//src/store-admin?ref=867dc76c5c365c30bc8aef3ff570d7aa0c3fa522'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource storeFrontImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'store-front-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-front/Dockerfile'
    tag: '867dc76'
    build: {
      source: 'git::https://github.com/Reshrahim/aks-store-demo.git//src/store-front?ref=867dc76c5c365c30bc8aef3ff570d7aa0c3fa522'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource virtualCustomerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'virtual-customer-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/virtual-customer/Dockerfile'
    tag: '867dc76'
    build: {
      source: 'git::https://github.com/Reshrahim/aks-store-demo.git//src/virtual-customer?ref=867dc76c5c365c30bc8aef3ff570d7aa0c3fa522'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource virtualWorkerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'virtual-worker-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/virtual-worker/Dockerfile'
    tag: '867dc76'
    build: {
      source: 'git::https://github.com/Reshrahim/aks-store-demo.git//src/virtual-worker?ref=867dc76c5c365c30bc8aef3ff570d7aa0c3fa522'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource makelineContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'makeline'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/makeline-service/main.go'
    containers: {
      service: {
        image: makelineImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3001
          }
        }
        env: {
          ORDER_DB_COLLECTION_NAME: {
            value: 'orders'
          }
          ORDER_DB_NAME: {
            value: 'orderdb'
          }
          ORDER_DB_URI: {
            valueFrom: {
              secretKeyRef: {
                secretName: mongoDb.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_QUEUE_PASSWORD: {
            value: rabbitMqPassword
          }
          ORDER_QUEUE_URI: {
            value: 'amqp://${rabbitMq.properties.host}:${rabbitMq.properties.port}'
          }
          ORDER_QUEUE_USERNAME: {
            value: 'username'
          }
        }
      }
    }
  }
}

resource orderContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'order'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/order-service/plugins/messagequeue.js'
    containers: {
      service: {
        image: orderImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          FASTIFY_ADDRESS: {
            value: '0.0.0.0'
          }
          ORDER_QUEUE_HOSTNAME: {
            value: rabbitMq.properties.host
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_QUEUE_PASSWORD: {
            value: rabbitMqPassword
          }
          ORDER_QUEUE_PORT: {
            value: string(rabbitMq.properties.port)
          }
          ORDER_QUEUE_USERNAME: {
            value: 'username'
          }
        }
      }
    }
  }
}

resource productContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'product'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/product-service/src/main.rs'
    containers: {
      service: {
        image: productImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3002
          }
        }
      }
    }
    connections: {
      rediscache: {
        source: redisCache.id
      }
    }
  }
}

resource storeAdminContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-admin'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-admin/nginx.conf'
    containers: {
      storeAdmin: {
        image: storeAdminImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8081
          }
        }
      }
    }
    connections: {
      makeline: {
        source: makelineContainer.id
      }
      order: {
        source: orderContainer.id
      }
      product: {
        source: productContainer.id
      }
    }
  }
}

resource storeFrontContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-front'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-front/nginx.conf'
    containers: {
      storeFront: {
        image: storeFrontImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8080
          }
        }
      }
    }
    connections: {
      order: {
        source: orderContainer.id
      }
      product: {
        source: productContainer.id
      }
    }
  }
}

resource virtualCustomerContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-customer'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/virtual-customer/src/main.rs#L9'
    containers: {
      virtualCustomer: {
        image: virtualCustomerImage.properties.imageReference
        env: {
          ORDERS_PER_HOUR: {
            value: '100'
          }
          ORDER_SERVICE_URL: {
            value: 'http://${orderContainer.properties.hosts.service}:3000/'
          }
        }
      }
    }
  }
}

resource virtualWorkerContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-worker'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/virtual-worker/src/main.rs#L10'
    containers: {
      virtualWorker: {
        image: virtualWorkerImage.properties.imageReference
        env: {
          MAKELINE_SERVICE_URL: {
            value: 'http://${makelineContainer.properties.hosts.service}:3001'
          }
          ORDERS_PER_HOUR: {
            value: '100'
          }
        }
      }
    }
  }
}
