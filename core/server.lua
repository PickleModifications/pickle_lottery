-- Auto-create the lottery tables on resource start so server owners don't
-- have to import the schema by hand. Statements are kept in sync with
-- _INSTALL/install.sql; every one is CREATE TABLE IF NOT EXISTS so
-- repeating it on every boot is a no-op against an already-installed DB.
--
-- Runs synchronously (MySQL.Sync.execute) so the schema is guaranteed to
-- exist before any module query fires. The migration only takes a handful
-- of milliseconds, and it's a one-shot during resource start — net-event
-- handlers from modules can't fire until clients interact with the lottery
-- well after this block completes.

SchemaReady = false

local SCHEMA_STATEMENTS = {
    [[
        CREATE TABLE IF NOT EXISTS `lottery_keno` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `numbers` longtext DEFAULT NULL,
            `receipts` longtext DEFAULT NULL,
            `date` timestamp NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`)
        )
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `lottery_moneyball` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `numbers` longtext DEFAULT NULL,
            `receipts` longtext DEFAULT NULL,
            `date` timestamp NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`) USING BTREE
        )
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `lottery_receipts` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `type` varchar(50) DEFAULT NULL,
            `data` longtext DEFAULT NULL,
            `date` timestamp NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`) USING BTREE
        )
    ]],
}

local function runSchema()
    for _, statement in ipairs(SCHEMA_STATEMENTS) do
        MySQL.Sync.execute(statement, {})
    end
    SchemaReady = true
    print(('[pickle_lottery] Schema bootstrap created/verified %d table(s).'):format(#SCHEMA_STATEMENTS))
end

-- MySQL.ready blocks the thread until the DB connection is up, which is
-- exactly what we want before running CREATE TABLE statements. If the
-- mysql-async build in use exposes ready as a function, call it; otherwise
-- fall back to a direct sync invocation (mysql-async always sets up the
-- connection before scripts execute their first sync call).
CreateThread(function()
    if MySQL and MySQL.ready then
        MySQL.ready(runSchema)
    else
        runSchema()
    end
end)
