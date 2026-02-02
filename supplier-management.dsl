workspace "CRM Enterprise Architecture" "Gestão de Fornecedores com integração ERP e Sistema X" {

    model {
        gestor = person "Gestor de Compras" "Usuário que gerencia fornecedores."

        # --- Sistemas Externos ---
        erpSystem = softwareSystem "ERP Corporativo" "Fonte da verdade para Empresas e destino de Fornecedores." "External System"
        systemX = softwareSystem "Sistema X" "Sistema interno que consome eventos de fornecedores." "External System"
        emailSystem = softwareSystem "Serviço de Email" "Notificações transacionais." "External System"

        crmSystem = softwareSystem "Sistema CRM" "Centraliza gestão de parceiros." {
            
            # Nível 2: Containers
            keycloak = container "Identity Provider" "Auth OIDC." "Keycloak" "Auth"
            spa = container "Web Application" "Interface React." "React" "Web Browser"
            apiGateway = container "API Gateway" "Load Balancer & Auth Check." "Kong"
            
            database = container "Database Principal" "Persistência de Empresas (Sync) e Fornecedores." "PostgreSQL" "Database"
            messageBroker = container "Message Broker" "Barramento para comunicação assíncrona." "Kafka/RabbitMQ" "Queue"
            
            erpOutWorker = container "ERP Outbound Worker" "Sincroniza Fornecedores para o ERP." "Worker"
            erpInWorker = container "ERP Inbound Worker" "Busca Empresas do ERP para o CRM." "Worker"
            systemXWorker = container "System X Worker" "Notifica o Sistema X sobre mudanças." "Worker"

            # Nível 3: CRM Core Service
            crmCore = container "CRM Core Service" "API de Negócio (Escalável Horizontalmente)." "Go/Node.js" {
                authMiddleware = component "Auth Middleware" "Valida JWT."
                supplierController = component "Supplier Controller" "Endpoints REST." "MVC Controller"
                supplierService = component "Supplier Service" "Casos de uso e regras de negócio." "Domain Logic"
                supplierRepository = component "Supplier Repository" "Acesso a dados." "Data Access"
                eventPublisher = component "Event Publisher" "Publica no Broker." "Messaging"
            }

            # --- Relacionamentos de Fluxo ---
            gestor -> spa "Usa"
            spa -> apiGateway "Chamadas API"
            apiGateway -> crmCore "Distribui carga"
            
            # Integração Inbound (Obtenção de Empresas)
            erpInWorker -> erpSystem "Consulta Empresas cadastradas"
            erpInWorker -> database "Atualiza cache local de Empresas"
            
            # Integração Outbound & Sistema X (Assíncrono)
            crmCore -> messageBroker "Publica: Created/Updated/Deleted"
            messageBroker -> erpOutWorker "Entrega evento"
            messageBroker -> systemXWorker "Entrega evento"
            
            erpOutWorker -> erpSystem "Atualiza Fornecedor"
            systemXWorker -> systemX "Notifica Sistema X"
            
            # Internos Core
            supplierController -> supplierService "Invoca"
            supplierService -> supplierRepository "Persiste"
            supplierService -> eventPublisher "Dispara Evento"
            supplierRepository -> database "SQL"
        }

        # Nível 1
        gestor -> crmSystem "Gerencia dados"
        crmSystem -> erpSystem "Sincroniza Empresas/Fornecedores"
        crmSystem -> systemX "Envia eventos de mudança"
    }

    views {
        systemContext crmSystem "V1_Contexto" {
            include *
            autoLayout lr
        }

        container crmSystem "V2_Containers" {
            include *
            autoLayout lr
        }

        component crmCore "V3_Componentes" {
            include *
            autoLayout tb
        }

        styles {
            # Removido o seletor genérico "Element" que causava o erro
            # Cada propriedade em sua própria linha
            element "Person" {
                shape Person
                background #08427b
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "External System" {
                background #999999
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Database" {
                shape Cylinder
                background #2f95c7
                color #ffffff
            }
            element "Queue" {
                shape Pipe
                background #2f95c7
                color #ffffff
            }
            element "Worker" {
                shape Robot
                background #666666
                color #ffffff
            }
            element "MVC Controller" {
                background #85bbf0
                color #ffffff
            }
            element "Domain Logic" {
                shape Hexagon
                background #1168bd
                color #ffffff
            }
            element "Messaging" {
                background #000000
                color #ffffff
            }
        }
    }
}