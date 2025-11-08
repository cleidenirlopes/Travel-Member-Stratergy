
-- ========================================
-- ### DESAFIO NOS ###
-- ========================================

-- Criar um novo banco de dados
CREATE DATABASE Desafio_NOS;

-- Usar o Assistente de Importação e Exportação para carregar os dados

-- Verificando os dados carregados

SELECT TOP 10 * FROM dbo.CATALOGO_PACOTES;
SELECT TOP 10 * FROM dbo.ENTRADAS_CANAIS;
SELECT TOP 10 * FROM dbo.RECOMENDACOES;
SELECT TOP 10 * FROM dbo.SOCIOS;
SELECT TOP 10 * FROM dbo.VENDAS_LOJAS;
SELECT TOP 10 * FROM dbo.VENDAS_OUTBOUND;
SELECT TOP 10 * FROM dbo.VENDAS_SAC;

-- Verificando as tabelas

SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';

-- Organizando os nomes das tabelas

EXEC sp_rename 'dbo.SOCIOS$', 'SOCIOS';
EXEC sp_rename 'dbo.CATALOGO_PACOTES$', 'CATALOGO_PACOTES';
EXEC sp_rename 'dbo.RECOMENDACOES$', 'RECOMENDACOES';
EXEC sp_rename 'dbo.ENTRADAS_CANAIS$', 'ENTRADAS_CANAIS';
EXEC sp_rename 'dbo.VENDAS_SAC$', 'VENDAS_SAC';
EXEC sp_rename 'dbo.VENDAS_LOJAS$', 'VENDAS_LOJAS';
EXEC sp_rename 'dbo.VENDAS_OUTBOUND$', 'VENDAS_OUTBOUND';

-- Renomeando as colunas

EXEC sp_rename 'dbo.VENDAS_SAC.[PACOTES_VENDIDOS#1]', 'P_SAC_VENDIDOS', 'COLUMN';
EXEC sp_rename 'dbo.VENDAS_LOJAS.[PACOTES_VENDIDOS#1]', 'P_LOJAS_VENDIDOS', 'COLUMN';
EXEC sp_rename 'dbo.VENDAS_OUTBOUND.[PACOTES_VENDIDOS#1]', 'P_OUTBOUND_VENDIDOS', 'COLUMN';

-- Confirmando a mudança nos nomes das colunas

SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('VENDAS_SAC', 'VENDAS_LOJAS', 'VENDAS_OUTBOUND')
ORDER BY TABLE_NAME, ORDINAL_POSITION;


-- ========================================
-- ### PERGUNTA 2 ###
-- ========================================

-- Receita total da agência (março e abril 2021)


WITH vendas_unificadas AS (
    SELECT DATA_VENDA, P_SAC_VENDIDOS AS DESC_PACOTE, Q_VENDIDAS, 'SAC' AS CANAL FROM dbo.VENDAS_SAC
    UNION ALL
    SELECT DATA_VENDA, P_LOJAS_VENDIDOS AS DESC_PACOTE, Q_VENDIDAS, 'LOJAS' AS CANAL FROM dbo.VENDAS_LOJAS
    UNION ALL
    SELECT DATA_VENDA, P_OUTBOUND_VENDIDOS AS DESC_PACOTE, Q_VENDIDAS, 'OUTBOUND' AS CANAL FROM dbo.VENDAS_OUTBOUND
)
SELECT
    FORMAT(DATA_VENDA, 'yyyy-MM') AS Mes,
    FORMAT(SUM(Q_VENDIDAS * c.PRECO), 'N2', 'pt-pt') AS Receita_Total
FROM vendas_unificadas v
JOIN dbo.CATALOGO_PACOTES c
    ON RTRIM(LTRIM(v.DESC_PACOTE)) = RTRIM(LTRIM(c.DESC_PACOTE))
WHERE DATA_VENDA BETWEEN '2021-03-01' AND '2021-04-30'  -- <- você só muda o período
GROUP BY FORMAT(DATA_VENDA, 'yyyy-MM')
ORDER BY Mes;



-- ========================================
-- ### PERGUNTA 3 ###
-- ========================================

-- Separar a análise por canal de vendas

WITH receita_por_canal AS (
    SELECT
        FORMAT(v.DATA_VENDA, 'yyyy-MM') AS Mes,
        v.CANAL,
        SUM(v.Q_VENDIDAS * c.PRECO) AS Receita
    FROM (
        SELECT DATA_VENDA, P_SAC_VENDIDOS AS DESC_PACOTE, Q_VENDIDAS, 'SAC' AS CANAL FROM dbo.VENDAS_SAC
        UNION ALL
        SELECT DATA_VENDA, P_LOJAS_VENDIDOS AS DESC_PACOTE, Q_VENDIDAS, 'LOJAS' AS CANAL FROM dbo.VENDAS_LOJAS
        UNION ALL
        SELECT DATA_VENDA, P_OUTBOUND_VENDIDOS AS DESC_PACOTE, Q_VENDIDAS, 'OUTBOUND' AS CANAL FROM dbo.VENDAS_OUTBOUND
    ) AS v
    JOIN dbo.CATALOGO_PACOTES c
        ON RTRIM(LTRIM(v.DESC_PACOTE)) = RTRIM(LTRIM(c.DESC_PACOTE))
    WHERE DATA_VENDA BETWEEN '2021-03-01' AND '2021-04-30'  -- <- alterar conforme necessário
    GROUP BY FORMAT(v.DATA_VENDA, 'yyyy-MM'), v.CANAL
)
SELECT
    Mes,
    CANAL,
    FORMAT(Receita, 'N2', 'pt-pt') AS Receita,
    FORMAT(LAG(Receita) OVER(PARTITION BY CANAL ORDER BY Mes), 'N2', 'pt-pt') AS Receita_Mes_Anterior,
    FORMAT(
        (Receita - LAG(Receita) OVER(PARTITION BY CANAL ORDER BY Mes))
        / LAG(Receita) OVER(PARTITION BY CANAL ORDER BY Mes) * 100, 'N2', 'pt-pt'
    ) AS Variacao_Percentual
FROM receita_por_canal
ORDER BY Mes, CANAL;



-- ========================================
-- ### DESCRICOES 3 ###
-- ========================================

/*
Pergunta 2 — Receita total da agência (março e abril de 2021)

O que foi feito:
- Juntei todas as vendas dos canais SAC, LOJAS e OUTBOUND para ter uma visão completa.
- Calculei quanto cada venda gerou de receita, usando o preço de cada pacote.
- Filtrei apenas os meses de março e abril de 2021.
- Somei as vendas por mês e por canal para ver o total.

Resultado:
- Março 2021: R$ 857.700,00 (LOJAS: 247.200,00 | OUTBOUND: 250.400,00 | SAC: 360.100,00)
- Abril 2021: R$ 731.700,00 (LOJAS: 236.100,00 | OUTBOUND: 148.800,00 | SAC: 346.800,00)
- A diferença total foi uma queda de R$ 126.000,00 de março para abril.
*/

/*
Pergunta 3 — Por que a receita caiu em abril de 2021

O que foi feito:
- Comparei a receita de abril com a de março para cada canal.
- Calculei a porcentagem de queda de cada um para entender qual teve mais impacto.

Resultado:
- LOJAS: -4,49% (queda pequena)
- OUTBOUND: -40,58% (queda muito grande, principal motivo da redução)
- SAC: -3,69% (queda pequena)

Conclusão:
O decréscimo de receita em abril de 2021 foi principalmente causado pela redução
drástica das vendas no canal OUTBOUND, que é responsável pela maior parte da queda.
LOJAS e SAC tiveram impacto muito menor.
*/

