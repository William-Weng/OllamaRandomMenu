import redis, json

def connect(host: str, port: int, db: int):
    """
    連線Redis
    
    參數:
        host: Redis的host
        port: Redis的port
        db: Redis的db
    """
    connect = redis.Redis(host=host, port=port, db=db)
    return connect

def keyExists(connect: redis.Redis, key: str):
    """
    測試Redis內的Key值是否存在

    參數:
        connect: redis連線
        key: 要測試的key值
    """
    if not connect.exists(key): return False
    return True

def setValue(connect: redis.Redis, list: list, key: str):
    """
    把值存起來

    參數:
        connect: redis連線
        list: 要存的List
        key: 要存的key值
    """
    jsonString = json.dumps(list)
    connect.delete(key)
    connect.set(key, jsonString)