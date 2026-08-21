extension radius

param environment string

@secure()
param registryUsername string

@secure()
param registryPassword string

@secure()
param rabbitmqPassword string

var sourceRef = 'git::https://github.com/Reshrahim/aks-store-demo.git//src'
var sourceRefSuffix = '?ref=7ce10c5110d6a52d3517dfb6d7a7b7b2edf2e5a5'

resource aksStoreApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'aks-store-demo'
  properties: {
    environment: environment
  }
}

resource ordersMongoDb 'Radius.Data/mongoDatabases@2025-08-01-preview' = {
  name: 'mongo'
  properties: {
    environment: environment
    application: aksStoreApp.id
    database: 'orderdb'
    codeReference: 'src/makeline-service/mongodb.go#L127'
  }
}

resource rabbitmqSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'rabbitmq-credentials'
  properties: {
    environment: environment
    application: aksStoreApp.id
    data: {
      password: {
        value: rabbitmqPassword
      }
    }
  }
}

resource ordersQueue 'Radius.Messaging/rabbitMQ@2025-08-01-preview' = {
  name: 'rabbitmq'
  properties: {
    environment: environment
    application: aksStoreApp.id
    queue: 'orders'
    username: 'radius'
    password: rabbitmqSecret.id
    codeReference: 'src/order-service/plugins/messagequeue.js#L22'
  }
}

resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: aksStoreApp.id
    data: {
      username: {
        value: registryUsername
      }
      password: {
        value: registryPassword
      }
    }
  }
}

var storeFrontNginxConf = join([
  'server {'
  '    listen       8080;'
  '    listen  [::]:8080;'
  '    server_name  localhost;'
  ''
  '    location / {'
  '        root   /usr/share/nginx/html;'
  '        index  index.html index.htm;'
  '        try_files $uri $uri/ /index.html;'
  '    }'
  ''
  '    error_page   500 502 503 504  /50x.html;'
  '    location = /50x.html {'
  '        root   /usr/share/nginx/html;'
  '    }'
  ''
  '    location /health {'
  '        default_type application/json;'
  '        return 200 \'{"status":"ok","version":"2.2.0"}\';'
  '    }'
  ''
  '    location /api/orders {'
  '        rewrite ^/api/orders$ / break;'
  '        rewrite ^/api/orders(/.*)$ $1 break;'
  '        proxy_pass http://${orderService.properties.hosts.order}:3000;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/products {'
  '        rewrite ^/api/products$ / break;'
  '        rewrite ^/api/products(/.*)$ $1 break;'
  '        proxy_pass http://${productService.properties.hosts.product}:3002;'
  '        proxy_http_version 1.1;'
  '    }'
  '}'
], '\n')

var storeAdminNginxConf = join([
  'server {'
  '    listen       8081;'
  '    listen  [::]:8081;'
  '    server_name  localhost;'
  ''
  '    client_max_body_size 10m;'
  ''
  '    location / {'
  '        root   /usr/share/nginx/html;'
  '        index  index.html index.htm;'
  '        try_files $uri $uri/ /index.html;'
  '    }'
  ''
  '    error_page   500 502 503 504  /50x.html;'
  '    location = /50x.html {'
  '        root   /usr/share/nginx/html;'
  '    }'
  ''
  '    location /health {'
  '        default_type application/json;'
  '        return 200 \'{"status":"ok","version":"2.2.0"}\';'
  '    }'
  ''
  '    location ~ ^/api/makeline/order/(?<id>\\w+) {'
  '        proxy_pass http://${makelineService.properties.hosts.makeline}:3001/order/$id;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/makeline/order {'
  '        proxy_pass http://${makelineService.properties.hosts.makeline}:3001/order;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/makeline/order/fetch {'
  '        proxy_pass http://${makelineService.properties.hosts.makeline}:3001/order/fetch;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/order {'
  '        rewrite ^/api/order$ / break;'
  '        rewrite ^/api/order(/.*)$ $1 break;'
  '        proxy_pass http://${orderService.properties.hosts.order}:3000;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/products/ {'
  '        proxy_pass http://${productService.properties.hosts.product}:3002/;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/products {'
  '        rewrite ^/api/products$ / break;'
  '        rewrite ^/api/products(/.*)$ $1 break;'
  '        proxy_pass http://${productService.properties.hosts.product}:3002;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location ~ ^/api/product/(?<id>\\w+) {'
  '        proxy_pass http://${productService.properties.hosts.product}:3002/$id;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/product {'
  '        rewrite ^/api/product$ / break;'
  '        rewrite ^/api/product(/.*)$ $1 break;'
  '        proxy_pass http://${productService.properties.hosts.product}:3002;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/product/ {'
  '        proxy_pass http://${productService.properties.hosts.product}:3002/;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/ai/health {'
  '        proxy_pass http://${productService.properties.hosts.product}:3002/ai/health;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/ai/generate/description {'
  '        proxy_pass http://${productService.properties.hosts.product}:3002/ai/generate/description;'
  '        proxy_http_version 1.1;'
  '    }'
  ''
  '    location /api/ai/generate/image {'
  '        proxy_pass http://${productService.properties.hosts.product}:3002/ai/generate/image;'
  '        proxy_http_version 1.1;'
  '        proxy_connect_timeout 30s;'
  '        proxy_read_timeout 300s;'
  '        proxy_send_timeout 300s;'
  '    }'
  '}'
], '\n')

resource storeFrontConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'store-front-nginx-config'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/store-front/nginx.conf'
    data: {
      'default.conf': {
        value: storeFrontNginxConf
      }
    }
  }
}

resource storeAdminConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'store-admin-nginx-config'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/store-admin/nginx.conf'
    data: {
      'default.conf': {
        value: storeAdminNginxConf
      }
    }
  }
}

resource orderServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'order-service-image'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/order-service/Dockerfile'
    build: {
      source: '${sourceRef}/order-service${sourceRefSuffix}'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource makelineServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'makeline-service-image'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/makeline-service/Dockerfile'
    build: {
      source: '${sourceRef}/makeline-service${sourceRefSuffix}'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource productServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'product-service-image'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/product-service/Dockerfile'
    build: {
      source: '${sourceRef}/product-service${sourceRefSuffix}'
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
    application: aksStoreApp.id
    codeReference: 'src/store-front/Dockerfile'
    build: {
      source: '${sourceRef}/store-front${sourceRefSuffix}'
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
    application: aksStoreApp.id
    codeReference: 'src/store-admin/Dockerfile'
    build: {
      source: '${sourceRef}/store-admin${sourceRefSuffix}'
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
    application: aksStoreApp.id
    codeReference: 'src/virtual-customer/Dockerfile'
    build: {
      source: '${sourceRef}/virtual-customer${sourceRefSuffix}'
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
    application: aksStoreApp.id
    codeReference: 'src/virtual-worker/Dockerfile'
    build: {
      source: '${sourceRef}/virtual-worker${sourceRefSuffix}'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource orderService 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'order-service'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/order-service/app.js'
    containers: {
      order: {
        image: orderServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          ORDER_QUEUE_HOSTNAME: {
            value: ordersQueue.properties.host
          }
          ORDER_QUEUE_PORT: {
            value: string(ordersQueue.properties.port)
          }
          ORDER_QUEUE_USERNAME: {
            value: 'radius'
          }
          ORDER_QUEUE_PASSWORD: {
            value: rabbitmqPassword
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          FASTIFY_ADDRESS: {
            value: '0.0.0.0'
          }
        }
      }
    }
  }
}

resource makelineService 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'makeline-service'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/makeline-service/main.go'
    containers: {
      makeline: {
        image: makelineServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3001
          }
        }
        env: {
          ORDER_QUEUE_URI: {
            value: 'amqp://${ordersQueue.properties.host}:${ordersQueue.properties.port}'
          }
          ORDER_QUEUE_USERNAME: {
            value: 'radius'
          }
          ORDER_QUEUE_PASSWORD: {
            value: rabbitmqPassword
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_DB_URI: {
            valueFrom: {
              secretKeyRef: {
                secretName: ordersMongoDb.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
          ORDER_DB_NAME: {
            value: 'orderdb'
          }
          ORDER_DB_COLLECTION_NAME: {
            value: 'orders'
          }
        }
      }
    }
  }
}

resource productService 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'product-service'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/product-service/src/app.rs'
    containers: {
      product: {
        image: productServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3002
          }
        }
      }
    }
  }
}

resource storeFront 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-front'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/store-front/Dockerfile'
    containers: {
      front: {
        image: storeFrontImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8080
          }
        }
        volumeMounts: [
          {
            volumeName: 'config'
            mountPath: '/etc/nginx/conf.d'
          }
        ]
      }
    }
    volumes: {
      config: {
        secretName: storeFrontConfig.name
      }
    }
  }
}

resource storeAdmin 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-admin'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/store-admin/Dockerfile'
    containers: {
      admin: {
        image: storeAdminImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8081
          }
        }
        volumeMounts: [
          {
            volumeName: 'config'
            mountPath: '/etc/nginx/conf.d'
          }
        ]
      }
    }
    volumes: {
      config: {
        secretName: storeAdminConfig.name
      }
    }
  }
}

resource virtualCustomer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-customer'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/virtual-customer/src/main.rs#L9'
    containers: {
      customer: {
        image: virtualCustomerImage.properties.imageReference
        env: {
          ORDER_SERVICE_URL: {
            value: 'http://${orderService.properties.hosts.order}:3000/'
          }
          ORDERS_PER_HOUR: {
            value: '100'
          }
        }
      }
    }
  }
}

resource virtualWorker 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-worker'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/virtual-worker/src/main.rs#L10'
    containers: {
      worker: {
        image: virtualWorkerImage.properties.imageReference
        env: {
          MAKELINE_SERVICE_URL: {
            value: 'http://${makelineService.properties.hosts.makeline}:3001'
          }
          ORDERS_PER_HOUR: {
            value: '100'
          }
        }
      }
    }
  }
}

resource storeFrontRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'store-front-route'
  properties: {
    environment: environment
    application: aksStoreApp.id
    codeReference: 'src/store-front/nginx.conf'
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: storeFront.id
          containerName: 'front'
          containerPort: 8080
        }
      }
    ]
  }
}
