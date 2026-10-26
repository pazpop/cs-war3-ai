// War3FT's SQLite database (data/sqlite3/war3ft.sq3), for our plugins that keep their own tables in it:
// #include "database.inc", after <sqlx>. Local SQLite: plain (not threaded) queries are fast enough, and simple to follow.

new Handle:g_db

// In plugin_init: opens the database; without it, the plugin stops.
stock connect_db()
{
	new error[128], code
	SQL_SetAffinity("sqlite")
	g_db = SQL_Connect(SQL_MakeDbTuple("", "", "", "war3ft"), code, error, charsmax(error))
	if (g_db == Empty_Handle)
		set_fail_state("SQLite: %s", error)
}

// Runs a query that returns nothing. Every value in it comes from the plugin or is escaped.
stock run(const format_string[], any:...)
{
	new query[512], error[128]
	vformat(query, charsmax(query), format_string, 2)
	new Handle:handle = SQL_PrepareQuery(g_db, "%s", query)
	if (!SQL_Execute(handle))
	{
		SQL_QueryError(handle, error, charsmax(error))
		log_amx("%s", error)
	}
	SQL_FreeHandle(handle)
}
