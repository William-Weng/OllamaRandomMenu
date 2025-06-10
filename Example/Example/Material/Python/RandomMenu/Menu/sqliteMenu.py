import json, pandas
import RandomMenu.configure as config
import RandomMenu.utility as util
import RandomMenu.Service.sqliteService as service
from sqlite3 import Cursor
from scipy.spatial.distance import cosine

def _parseInsertValues_(dataFrame: pandas.DataFrame):
    """
    將讀出的CSV資料 => SQLite要存的格式

    參數:
        dataFrame: CSV資料
    """
    insertValues = []
    vectorList = util.vectorList(dataFrame)

    for index in range(len(vectorList)):
        info = vectorList[index]
        value = info["question"], json.dumps(info["vector"])
        insertValues.append(value)

    return insertValues

def _initVectorValues_(cursor: Cursor, dataFrame: pandas.DataFrame, tableName: str, isRefresh: bool):
    """
    將CSV資料 => 向量 => 存入SQLite

    參數:
        cursor: SQLite資料庫指標
        dataFrame: CSV資料
        tableName: 資料表名稱
        isRefresh: 是否要重新生成Vector
    """

    if isRefresh:
        cursor.execute(f'DROP TABLE IF EXISTS {tableName}')

        cursor.execute(f'''
        CREATE TABLE IF NOT EXISTS {tableName} (
            id INTEGER PRIMARY KEY,
            question TEXT UNIQUE NOT NULL,
            vector TEXT NOT NULL
        )''')

        insertValues = _parseInsertValues_(dataFrame)
        cursor.executemany(f'INSERT OR IGNORE INTO {config.MenuTable} (question, vector) VALUES (?, ?)', insertValues)

def _similarIndexList_(cursor: Cursor, input: str, threshold: float):
    """
    將輸入資料 => 相似度之內的資料Index

    參數:
        cursor: SQLite資料表指標
        input: 輸入資料
        threshold: 相似度的基準值 (0.0 ~ 1.0)
    """

    indexArray = []
    inputVector = util.embeddings(input)
    cursor.execute(f'SELECT * FROM {config.MenuTable}')

    for row in cursor.fetchall():

        index = row[0] - 1
        vector = json.loads(row[2])
        similarity = 1 - cosine(inputVector, vector)
        similarMap = util.parseSimilarMap(similarity=similarity, threshold=threshold, index=index)

        if similarMap is not None: indexArray.append(similarMap)

    return indexArray

def questions(input: str, isRefresh: bool, count: int, threshold: float, table = config.CSVPath, database = config.DatabasePath):
    """
    取得選單問題 => {"result:":{"menu":[<CSV中的選單問題>],"question":[<比較後產生的近似問題>]},"error":<錯誤訊息>}

    參數:
        input: 輸入文字
        isRefresh: 是否要重新生成Vector數值
        count: 隨機幾筆選單
        threshold: 相似值的基準值 (0.0 ~ 1.0)
        table: 問題列表的CSV路徑檔名
        database: SQLite資料庫路徑名稱
    """
    dataFrame = pandas.read_csv(table)

    if len(input) == 0:
        randomMenu = util.combineRandomMenu(dataFrame, count)
        return { "result": { "menu": randomMenu, "question": None }, "error": None }, 200

    connect, cursor = service.createDatabase(database)
    _initVectorValues_(cursor=cursor, dataFrame=dataFrame, tableName=config.MenuTable, isRefresh=isRefresh)

    if not service.menuTableExists(cursor=cursor, tableName=config.MenuTable):
        error = {}
        error["message"] = "該資料表不存在…"
        randomMenu = util.combineRandomMenu(dataFrame, count)
        return { "result": { "menu": randomMenu, "question": None }, "error": error }, 404

    indexArray = _similarIndexList_(cursor=cursor, input=input, threshold=threshold)
    rows = util.similarList(dataFrame, indexArray)
    questions = util.combineQuestions(rows, indexArray)

    connect.commit()
    connect.close()

    return util.randomQuestions(questions=questions, count=count, dataFrame=dataFrame)

def refreshVectors(database = config.DatabasePath, table = config.CSVPath):
    """
    刷新 / 重建CSV內的文字向量值 => SQLite

    參數:
        table: 問題列表的CSV路徑名稱
        database: SQLite資料庫路徑名稱
    """
    dataFrame = pandas.read_csv(table)
    connect, cursor = util.createDatabase(database)
    _initVectorValues_(cursor=cursor, dataFrame=dataFrame, tableName=config.MenuTable, isRefresh=True)

    connect.commit()
    connect.close()
