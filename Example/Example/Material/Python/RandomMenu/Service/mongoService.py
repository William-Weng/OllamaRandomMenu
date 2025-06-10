from pymongo import MongoClient, ASCENDING
from pymongo.database import Database, Collection

def createDatabase(url: str, name: str):
    """
    建立資料庫

    參數:
        url: 資料庫url
        name: 資料庫名稱
    """
    client = MongoClient(url)
    database = client[name]

    return database

def createCollection(database: Database, name: str):
    """
    建立資料表 (空集合)

    參數:
        database: 資料庫指標
        name: 資料表名稱 (集合)
    """
    return database.create_collection(name)

def linkCollection(database: Database, name: str):
    """
    選擇資料表 (集合)

    參數:
        database: 資料庫指標
        name: 資料表名稱 (集合)
    """
    collection = database[name]
    return collection

def selectCollection(collection: Collection, query: dict = {}, sort: dict = None, skip: int = None, limit: int = None):
    """
    搜尋資料表 (集合)

    參數:
        collection: 資料表指標 (集合)
        query: 搜尋條件
        sort: 排序條件
        skip: 跳過幾筆資料
        limit: 最多回傳幾筆資料
    """

    result = collection.find(query)

    if skip is not None: result = result.skip(skip)
    if limit is not None: result = result.limit(limit)
    if sort is not None: result = result.sort(sort)

    return result

def collectionExists(database: Database, name: str):
    """
    該資料表是否存在 (集合)

    參數:
        collection: 資料表指標 (集合)
        field: 欄位名稱
    """
    if name in database.list_collection_names(): return True
    return False

def deleteCollection(database: Database, name: str):
    """
    刪除資料表 (集合)

    參數:
        database: 資料庫指標
        name: 資料表名稱 (集合)
    """
    dict = database.drop_collection(name)
    return dict

def insertDocument(collection: Collection, document: dict):
    """
    新增單筆資料

    參數:
        collection: 資料表指標 (集合)
        document: 要新增資料的樣式
    """
    result = collection.insert_one(document)
    return result

def updateDocument(collection: Collection, query: dict, document: dict):
    """
    更新單筆資料

    參數:
        collection: 資料表指標 (集合)
        query: 查詢條件 (集合)
        document: 要更新資料的樣式
    """
    result = collection.update_one(query, {"$set": document})
    return result

def uniqueField(collection: Collection, name: str):
    """
    建立欄位唯一索引

    參數:
        collection: 資料表指標 (集合)
        name: 欄位名稱
    """
    return collection.create_index([(name, ASCENDING)], unique=True)
