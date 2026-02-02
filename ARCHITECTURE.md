# High Level Design (HLD) - Sistema CRM de Fornecedores

**Versão:** 1.0.0  
**Status:** Draft (Em Elaboração)

---

## 1. Visão Executiva
Este documento detalha a arquitetura da solução para o novo **CRM de Gestão de Empresas e Fornecedores**. O sistema foi projetado para centralizar o cadastro de parceiros comerciais, garantindo alta disponibilidade, escalabilidade horizontal e integração desacoplada com o ecossistema corporativo (ERP Legado e Sistema X).

### Principais Drivers Arquiteturais
* **Assincronismo:** Uso de mensageria para evitar acoplamento temporal com sistemas externos.
* **Escalabilidade:** Separação de responsabilidades em *Workers* e APIs *Stateless*.
* **Segurança:** Centralização de identidade via protocolo OIDC (Keycloak).
* **Consistência Eventual:** Sincronização resiliente de dados entre o CRM e o ERP.

---

## 2. Arquitetura da Solução (C4 Model)

Abaixo apresentamos os diagramas arquiteturais seguindo a notação C4 Model, indo do nível macro (Contexto) ao detalhe de implementação (Componentes).

### 2.1. Nível 1: Diagrama de Contexto
Este diagrama situa o Sistema CRM dentro do ecossistema da empresa. Ele ilustra as fronteiras do sistema e suas interações com usuários e parceiros de integração.

**Fluxos Principais:**
1.  **Gestor de Compras:** Interage com o CRM para realizar cadastros.
2.  **ERP Corporativo:** Fonte da verdade para "Empresas" e destino dos dados de "Fornecedores".
3.  **Sistema X:** Sistema interno que deve ser notificado reativamente sobre mudanças na base de fornecedores.
4.  **Serviço de Email:** Utilizado para notificações transacionais.

![Diagrama de Contexto](/images/V1_Contexto.png)
*Figura 1: Visão do Contexto do Sistema*

![Legenda Contexto](/images/V1_Contexto-key.png)
*Figura 2: Legenda do Diagrama de Contexto*

---

### 2.2. Nível 2: Diagrama de Contêineres
Neste nível, detalhamos as unidades implantáveis e a estratégia de comunicação (Síncrona vs Assíncrona). A arquitetura adota um modelo baseado em microsserviços e workers.

**Decisões de Design:**
* **API Gateway:** Ponto único de entrada para garantir segurança e balanceamento de carga.
* **Message Broker (Fan-out):** O barramento de eventos distribui mensagens para múltiplos consumidores (`ERP Outbound Worker` e `System X Worker`) simultaneamente, garantindo que a lentidão de um sistema não afete o outro.
* **Sincronização de Empresas (Inbound):** O `ERP Inbound Worker` popula o banco local do CRM com dados do ERP, garantindo performance nas consultas de tela.

![Diagrama de Containers](/images/V2_Containers.png)
*Figura 3: Visão de Containers e Infraestrutura*

![Legenda Containers](/images/V2_Containers-key.png)
*Figura 4: Legenda do Diagrama de Containers*

---

### 2.3. Nível 3: Diagrama de Componentes (CRM Core)
Focamos aqui no interior do microsserviço principal, o **CRM Core Service**. A estrutura segue a **Clean Architecture** (Arquitetura Limpa) para garantir testabilidade e independência de frameworks.

**Estrutura Interna:**
* **Controller:** Camada de entrada (HTTP/REST) e validação de DTOs.
* **Service (Domain Logic):** Orquestra as regras de negócio e casos de uso.
* **Repository:** Abstração para o acesso ao banco de dados PostgreSQL.
* **Event Publisher:** Componente responsável por traduzir eventos de domínio em mensagens de infraestrutura (JSON) para o Broker.

![Diagrama de Componentes](/images/V3_Componentes.png)
*Figura 5: Visão detalhada dos Componentes do CRM Core*

![Legenda Componentes](/images/V3_Componentes-key.png)
*Figura 6: Legenda do Diagrama de Componentes*

---

## 3. Detalhamento dos Fluxos de Dados

### 3.1. Criação de Fornecedor (Fluxo Assíncrono)
Para garantir responsividade ao usuário, o processo de integração é desacoplado:

1.  Usuário envia `POST /suppliers` para o **CRM Core**.
2.  **CRM Core** salva no PostgreSQL e retorna `201 Created` imediatamente.
3.  **CRM Core** publica evento `SupplierCreated` no **Message Broker**.
4.  **ERP Outbound Worker** consome o evento $\to$ Chama API do ERP.
5.  **System X Worker** consome o evento $\to$ Notifica o Sistema X.

### 3.2. Consulta de Empresas (Sincronização Inbound)
Para evitar latência de rede consultando o ERP em tempo real a cada carregamento de página:

1.  **ERP Inbound Worker** roda periodicamente (job) ou escuta eventos do ERP.
2.  Dados de empresas são replicados/atualizados no banco local do CRM.
3.  A interface do usuário consulta o banco local, obtendo resposta em milissegundos.

---

## 4. Requisitos Não-Funcionais Atendidos

| Requisito | Solução Adotada |
| :--- | :--- |
| **Escalabilidade** | O `CRM Core` é *stateless* e pode escalar horizontalmente atrás do Gateway. Os *Workers* podem escalar independentemente baseados no tamanho da fila. |
| **Integração ERP** | Isolada via Workers. Se o ERP cair, as mensagens acumulam na fila e são processadas quando ele voltar (Retry Pattern). |
| **Segurança** | Autenticação delegada ao **Keycloak** (OIDC). O Gateway valida a assinatura (JWKS) dos tokens antes de aceitar requisições. |
| **Auditoria** | Todos os eventos de mudança de estado são persistidos no Broker, permitindo rastreabilidade. |

---

## 5. Stack Tecnológica Sugerida

* **Backend:** Java / Quarkus ou Spring Boot
* **Frontend:** TypeScript / Angular
* **Banco de Dados:** H2, PostgreSQL ou SQL Server
* **Message Broker:** RabbitMQ ou Apache Kafka
* **Identity Provider:** Keycloak
* **Gateway:** Kong ou Nginx
* **Runtime:** OpenShift ou OKD