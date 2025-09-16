-- Custom function to parse key-value pairs from a log string into a Map(String, String).
CREATE FUNCTION IF NOT EXISTS parseLogKeyValueCore AS (body, max_equals) -> multiIf (
    isValidJson(body),
    CAST(
        JSONExtractKeysAndValues(body, 'String', 'String'),
        'Map(String, String)'
    ),
    countMatches(body, '=') < max_equals,
    extractKeyValuePairsWithEscaping(
        replaceAll(replaceAll(body, ';;', ''), '|', ' '),
        '=',
        ';,\n '
    ),
    extractKeyValuePairs('')
);

-- Wrapper of parse function to control max_equals parameter.
CREATE FUNCTION IF NOT EXISTS parseLogKeyValueWithMaxEquals AS (body, max_equals) -> parseLogKeyValueCore(body, max_equals);

-- Parse function with max_equals set to 1000, this will be used by end-users
CREATE FUNCTION IF NOT EXISTS parseLogKeyValue AS (body) -> parseLogKeyValueCore(body, 1000);