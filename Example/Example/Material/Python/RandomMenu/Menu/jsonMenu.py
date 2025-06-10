import pandas
import RandomMenu.utility as util
import RandomMenu.configure as config
import RandomMenu.Service.jsonService as service

def questions(input: str, isRefresh: bool, count: int, threshold: float, encoding = config.Encoding, table = config.CSVPath, file = config.JSONPath):
    """
    取得選單問題 => {"result:":{"menu":[<CSV中的選單問題>],"question":[<比較後產生的近似問題>]},"error":<錯誤訊息>}

    參數:
        input: 輸入文字
        isRefresh: 是否要重新生成Vector數值
        count: 隨機幾筆選單
        threshold: 相似值的基準值 (0.0 ~ 1.0)
        encoding: 字元編碼
        table: 問題列表的CSV路徑名稱
        file: 記錄問題向量的JSON路徑名稱
    """

    dataFrame = pandas.read_csv(table)

    if len(input) == 0:
        randomMenu = util.combineRandomMenu(dataFrame, count)
        return { "result": { "menu": randomMenu, "question": None }, "error": None }, 200

    if isRefresh: refreshVectors(encoding=encoding, table=table, file=file)
    
    if not util.fileExists(file):
        error = {}
        error["message"] = "該JSON文件不存在…"
        randomMenu = util.combineRandomMenu(dataFrame, count)
        return { "result": { "menu": randomMenu, "question": None }, "error": error }, 404

    vectorArray = util.readVectorJSON(file, encoding)
    indexArray = util.similarIndexList(input, vectorArray, threshold)
    rows = util.similarList(dataFrame, indexArray)
    questions = util.combineQuestions(rows, indexArray)

    return util.randomQuestions(questions=questions, count=count, dataFrame=dataFrame)

def refreshVectors(encoding = config.Encoding, table = config.CSVPath, file = config.JSONPath):
    """
    刷新 / 重建CSV內的文字向量值 => JSON

    參數:
        encoding: 字元編碼
        table: 問題列表的CSV路徑名稱
        file: 記錄問題向量的JSON路徑名稱
    """
    dataFrame = pandas.read_csv(table)
    vectors = util.vectorList(dataFrame)
    service.writeVectorJSON(vectors, file, encoding)
