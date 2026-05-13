---

# 📋 SisGESC – Sistema de Gestão do CCA Bom Jesus do Cangaíba

> **Script único de instalação** – Execute um arquivo e tenha o banco de dados OLTP + OLAP totalmente configurado.

## 🚀 Como executar o script único de instalação

### 1️⃣ Pré‑requisitos

Antes de executar, certifique-se de que seu ambiente atende aos requisitos:

- **MySQL Server 8.0+** instalado e em execução
- **MySQL Workbench** (recomendado) ou qualquer cliente SQL
- Usuário com privilégios para:
  - `CREATE DATABASE`
  - `CREATE TABLE`
  - `CREATE TRIGGER`
  - `CREATE EVENT`
  - `CREATE PROCEDURE`
  - `CREATE FUNCTION`
- O **Event Scheduler** do MySQL deve estar ligado (verifique e ative se necessário):
  ```sql
  SET GLOBAL event_scheduler = ON;
  ```

### 2️⃣ Baixar o script principal

No repositório, localize o arquivo:

```
Sisgesc_run_all.sql
```

Faça o download ou clone o repositório para sua máquina.

### 3️⃣ Abrir e executar no MySQL Workbench

1. Abra o **MySQL Workbench**.
2. Conecte‑se ao seu servidor MySQL local (ou remoto).
3. No menu superior, clique em:
   ```
   File → Open SQL Script
   ```
4. Selecione o arquivo `Sisgesc_run_all.sql`.
5. Com o script aberto, clique no ícone **⚡ Execute** (ou pressione `Ctrl + Shift + Enter`).

### 4️⃣ O que acontece automaticamente

O script principal orquestra a execução **sequencial e idempotente** de todos os submódulos:

| Ordem | Script                       | Função                                                       |
| ----- | ---------------------------- | ------------------------------------------------------------ |
| 1     | `reset.sql`                  | Remove bancos antigos (`sisgesc_oltp` / `sisgesc_olap`)      |
| 2     | `sisgesc_OLTP.sql`           | Cria tabelas, triggers, views, procedures e eventos (OLTP)   |
| 3     | `sisgesc_DML_OLTP.sql`       | Popula todas as 24 tabelas com dados de exemplo              |
| 4     | `consultas.sql`              | Executa consultas analíticas de exemplo                     |
| 5     | `sisgesc_OLAP.sql`           | Cria e popula o Data Warehouse (OLAP)                        |

> ⚠️ Nenhuma intervenção manual é necessária. O script é **idempotente** – pode ser reexecutado quantas vezes desejar sem causar duplicação ou erros.

### 5️⃣ Verificações pós‑execução

Para confirmar que tudo funcionou corretamente, execute as consultas abaixo no MySQL Workbench:

```sql
-- Ver os dois bancos criados
SHOW DATABASES LIKE 'sisgesc%';

-- Usar o banco OLTP e listar as 24 tabelas
USE sisgesc_oltp;
SHOW TABLES;

-- Ver triggers ativas
SHOW TRIGGERS;

-- Ver eventos programados
SHOW EVENTS;

-- Ver procedures armazenadas
SHOW PROCEDURE STATUS WHERE Db = 'sisgesc_oltp';
```

Todos os comandos devem retornar sem erros.

### 6️⃣ Resultado esperado

- Banco `sisgesc_oltp` – completo com dados de exemplo
- Banco `sisgesc_olap` – estruturado para BI/IA
- Todas as **regras de negócio** implementadas via triggers, procedures e eventos
- **Consultas analíticas** executadas com sucesso
- Ambiente pronto para receber análises de **previsão de evasão escolar**

---

## 🧩 Estrutura do repositório (para referência)

```text
📁 Atividade-Sisgesc/
│
├── 📁 docs/
│   ├── Deerdbdiagram.pdf
│   └── DEERMYSQL.pdf
│
├── 📁 scripts/
│   ├── 📁 01_ddl/          → sisgesc_OLTP.sql
│   ├── 📁 02_dml/          → sisgesc_DML_OLTP.sql
│   ├── 📁 03_queries/      → consultas.sql
│   ├── 📁 04_etl_dw/       → sisgesc_OLAP.sql
│   └── 📁 05_reset/        → reset.sql
│
├── README.md
└── Sisgesc_run_all.sql     ← ⭐ SCRIPT PRINCIPAL
```

---

## 🛠️ Tecnologias utilizadas

- **MySQL 8.0** – SGBD relacional
- **MySQL Workbench** – ambiente de desenvolvimento
- **dbdiagram.io** – modelagem do diagrama ER

---

## 👥 Equipe de desenvolvimento

| Nome                              |
| --------------------------------- |
| Ana Clara Gregório dos Santos     |
| Agatha Ribeiro                    |
| Bruno Oliveira Theodoro           |
| Cauê Porto de Andrade             |
| Dandhara Fernandes de Campos Lima |
| Duquesnio Daniel Bandessa         |
| Gabriela Dias Santos Barros       |
| Kauan Alba Elias                  |
| Rayssa dos Santos                 |
| Yasmim Bueno Miranda da Silva     |

---

## 🏛️ Instituição

Projeto extensionista desenvolvido para a **Universidade Cidade de São Paulo – UNICID**  
Disciplina: Banco de Dados – Ano: 2026

---

## ✅ Resumo para entrega

Ao executar `Sisgesc_run_all.sql` você terá:

- ✅ Banco OLTP normalizado (24 tabelas)
- ✅ Banco OLAP dimensional (estrela)
- ✅ Triggers, procedures, eventos e funções
- ✅ Dados de exemplo consistentes
- ✅ Consultas prontas para análise
- ✅ Evidência de execução sem erros (print da saída do MySQL)

📌 **Dica para documentar a entrega:** tire prints da janela de mensagens do MySQL Workbench após a execução, mostrando que todos os scripts foram processados com sucesso (sem erros vermelhos).
