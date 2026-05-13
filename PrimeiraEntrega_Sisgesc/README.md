#  Sisgesc Primeira Entrega
## Visão geral do projeto
Sistema de banco de dados para o *CCA Bom Jesus de Cangaíba*, organizado em três módulos integrados: RH, Alunos e Financeiro, com foco em integridade referencial, rastreabilidade dos dados e suporte a análises de BI/IA para previsão de evasão escolar.

## Atualizações da Primeira entrega para a mais atual
Durante o desenvolvimento do projeto, diversas melhorias significativas foram implementadas em relação à primeira entrega, corrigindo inconsistências e aprimorando a qualidade geral do banco de dados.
Correção das chaves primárias e estrangeiras (PKs e FKs)
Na versão inicial, havia erros na definição e no relacionamento entre as chaves primárias e estrangeiras das tabelas, o que comprometia a integridade referencial do banco de dados. Esses problemas foram identificados e corrigidos, garantindo que os relacionamentos entre as entidades estejam adequadamente mapeados e que as restrições de integridade sejam respeitadas.
Revisão das triggers
As triggers presentes na primeira entrega apresentavam falhas na lógica de execução, podendo gerar comportamentos inesperados durante operações de inserção, atualização ou exclusão. Na versão atual, foram reescritas e testadas para garantir que disparem corretamente nas situações previstas.
Aprimoramento das consultas (SELECTs e LEFT JOINs)
As consultas SQL foram revisadas e otimizadas. Os SELECTs foram ajustados para retornar apenas as colunas necessárias, evitando redundâncias, e os LEFT JOINs foram corrigidos para garantir que os relacionamentos entre as tabelas sejam realizados de forma eficiente e sem perda de dados relevantes.
Substituição de VARCHARs desnecessários por ENUMs
Um dos principais problemas da primeira entrega era o uso excessivo do tipo VARCHAR em campos que possuem um conjunto fixo e predefinido de valores. Isso tornava o banco de dados mais suscetível a inconsistências nos dados e menos eficiente. Na versão atual, esses campos foram convertidos para o tipo ENUM, o que garante maior integridade dos dados, melhor desempenho nas consultas e uma modelagem mais semântica e legível.
