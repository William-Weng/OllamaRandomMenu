import pandas, json
import RandomMenu.utility as util
import RandomMenu.configure as config
import RandomMenu.Service.redisService as service

def questions(input: str, isRefresh: bool, count: int, threshold: float, table = config.CSVPath, host = config.RedisHost, port = config.RedisPort, key = config.MenuTable):
    """
    取得選單問題 => {"result:":{"menu":[<CSV中的選單問題>],"question":[<比較後產生的近似問題>]},"error":<錯誤訊息>}

    參數:
        input: 輸入文字
        isRefresh: 是否要重新生成Vector數值
        count: 隨機幾筆選單
        threshold: 相似值的基準值 (0.0 ~ 1.0)
        table: 問題列表的CSV路徑檔名
        host: Redis的host
        port: Redis的port
        key: 要存在redis內的key值
    """
    dataFrame = pandas.read_csv(table)
    connect = service.connect(host=host, port=port, db=0)

    if len(input) == 0:
        randomMenu = util.combineRandomMenu(dataFrame, count)
        return { "result": { "menu": randomMenu, "question": None }, "error": None }, 200

    if isRefresh:
        vectors = util.vectorList(dataFrame)
        service.setValue(connect=connect, list=vectors, key=key)

    if not service.keyExists(connect=connect, key=key):
        error = {}
        error["message"] = "該Key值不存在…"
        randomMenu = util.combineRandomMenu(dataFrame, count)
        return { "result": { "menu": randomMenu, "question": None }, "error": error }, 404

    jsonString = connect.get(key)
    vectorArray = json.loads(jsonString)

    indexArray = util.similarIndexList(input, vectorArray, threshold)
    rows = util.similarList(dataFrame, indexArray)
    questions = util.combineQuestions(rows, indexArray)

    return util.randomQuestions(questions=questions, count=count, dataFrame=dataFrame)

def refreshVectors(table = config.CSVPath, host = config.RedisHost, port = config.RedisPort, key = config.MenuTable):
    """
    刷新 / 重建CSV內的文字向量值 => Redis

    參數:
        encoding: 字元編碼
        table: 問題列表的CSV路徑名稱
        file: 記錄問題向量的JSON路徑名稱
    """
    dataFrame = pandas.read_csv(table)
    vectors = util.vectorList(dataFrame)
    connect = service.connect(host=host, port=port, db=0)

    service.setValue(connect=connect, list=vectors, key=key)
