import pandas
import RandomMenu.configure as config
import RandomMenu.utility as util
import RandomMenu.Service.mongoService as service
from pymongo.database import Database

def _writeVectorCollection_(vectors: list, database: Database, collectionName: str):
    """
    寫入文字向量 => 資料庫

    參數:
        vectors: 向量
        database: 資料庫指標
        collectionName: 資料表名稱 (集合)
    """
    service.deleteCollection(database=database, name=collectionName)
    collection = service.createCollection(database=database, name=collectionName)
    
    for vector in vectors:
        try:
            service.insertDocument(collection=collection, document=vector)
        except Exception as error:
            break

def questions(input: str, isRefresh: bool, count: int, threshold: float, table = config.CSVPath, url = config.MongoAPI, databaseName = config.MenuDatabase, collectionName = config.MenuTable):
    """
    取得選單問題 => {"result:":{"menu":[<CSV中的選單問題>],"question":[<比較後產生的近似問題>]},"error":<錯誤訊息>}

    參數:
        input: 輸入文字
        isRefresh: 是否要重新生成Vector數值
        count: 隨機幾筆選單
        threshold: 相似值的基準值 (0.0 ~ 1.0)
        table: 問題列表的CSV路徑名稱
        url: MongoDB的位置
        databaseName: 資料庫名稱
        collectionName: 資料表名稱 (集合)
    """

    dataFrame = pandas.read_csv(table)
    database = service.createDatabase(url=url, name=databaseName)

    if len(input) == 0:
        randomMenu = util.combineRandomMenu(dataFrame, count)
        return { "result": { "menu": randomMenu, "question": None }, "error": None }, 200

    if isRefresh:
        vectors = util.vectorList(dataFrame)
        _writeVectorCollection_(vectors=vectors, database=database, collectionName=collectionName)

    if not service.collectionExists(database=database, name=collectionName):
        error = {}
        error["message"] = "該集合不存在…"
        randomMenu = util.combineRandomMenu(dataFrame, count)
        return { "result": { "menu": randomMenu, "question": None }, "error": error }, 404
    
    collection = service.linkCollection(database=database, name=collectionName)
    service.uniqueField(collection=collection, name="question")
    
    vectorArray = list(collection.find())    
    indexArray = util.similarIndexList(input, vectorArray, threshold)
    rows = util.similarList(dataFrame, indexArray)
    questions = util.combineQuestions(rows, indexArray)

    database.client.close()

    return util.randomQuestions(questions=questions, count=count, dataFrame=dataFrame)

def refreshVectors(table = config.CSVPath, url = config.MongoAPI, databaseName = config.MenuDatabase, collectionName = config.MenuTable):
    """
    刷新 / 重建CSV內的文字向量值 => MongoDB

    參數:
        table: 問題列表的CSV路徑名稱
        url: MongoDB的位置
        databaseName: 資料庫名稱
        collectionName: 資料表名稱 (集合)
    """
    database = service.createDatabase(url=url, name=databaseName)
    dataFrame = pandas.read_csv(table)
    vectors = util.vectorList(dataFrame)
    _writeVectorCollection_(vectors=vectors, database=database, collectionName=collectionName)

    database.client.close()

