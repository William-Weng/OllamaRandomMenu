from sqlite3 import Cursor
import sqlite3

def createDatabase(name: str):
    """
    建立資料庫 + 資料表

    參數:
        name: 資料庫名稱
    """
    connect = sqlite3.connect(name)
    cursor = connect.cursor()

    return connect, cursor

def menuTableExists(cursor: Cursor, tableName: str):
    """
    測試該資料表是否存在

    參數:
        cursor: SQLite資料庫指標
        tableName: 資料表名稱
    """
    cursor.execute(
    f"""
    SELECT name FROM sqlite_master WHERE type='table' AND name='{tableName}'
    """)
    
    firstRow = cursor.fetchone()
    return firstRow is not None
