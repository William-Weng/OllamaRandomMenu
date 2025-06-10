import RandomMenu.Menu.mongoMenu as menu
import RandomMenu.configure as config
import RandomMenu.Service.mongoService as service
import RandomMenu.utility as util
from datetime import datetime
from flask import Flask, request, jsonify, Response

app = Flask(__name__)

# 刷新 / 重建CSV內的文字向量值
@app.route('/menu/refresh', methods=['GET'])
def refreshMenuVectors():
    menu.refreshVectors()
    return Response(status=200)

# 相似度選單 / 隨機選單
# => 參數：{"input":"<問題>","count":3,"threshold":0.7}
# => 結果：{"error":{"message":<錯誤訊息>},"result":{"menu":[<隨機選單>],"question":[<與問題相似的選單>]}}
@app.route('/menu', methods=['POST'])
def similarMenu():

    input = ""
    isRefresh = False
    count = 3
    threshold = 0.7

    if request.is_json:

        json = request.json

        _input = json.get('input')
        _count = json.get("count")
        _threshold = json.get("threshold")

        if _input is not None: input = _input
        if _count is not None: count = _count
        if _threshold is not None: threshold = _threshold

    result, code = menu.questions(input=input, isRefresh=isRefresh, count=count, threshold=threshold)
    return jsonify(result), code

# 搜尋特定位置的選單
# => 參數：{"indices": [int]}
# => 結果：{"error":{"message":nil},"result":{"menu":[<隨機選單>],"question":nil}}
@app.route('/menu/search', methods=['POST'])
def searchMenu():

    indices = None

    if request.is_json:
        json = request.json
        indices = json.get('indices', [])

    return util.searchMenu(indices=indices)

# 取得對話記錄 (倒序排列)
# => 參數：?skip=<跳過的筆數>&limit=<取得的筆數>
# => 結果：{"result":[{"role":<角色>,"content":<內容>,"timestamp":<時間戳記>,"createDate":<建立日期>}]}
@app.route('/message', methods=['GET'])
def readMessage(url = config.MongoAPI, databaseName = config.MenuDatabase, collectionName = config.MessageTable):
    
    skip = request.args.get('skip', 0)
    limit = request.args.get('limit', 10)

    database = service.createDatabase(url=url, name=databaseName)
    collection = service.linkCollection(database=database, name=collectionName)

    messages = list(service.selectCollection(collection=collection, sort={"timestamp": -1}, skip=int(skip), limit=int(limit)))    
    database.client.close()
    result = []

    for index in range(len(messages)):

        role = messages[index]["role"]
        name = messages[index]["name"]
        content = messages[index]["content"]
        timestamp = messages[index]["timestamp"]
        createDate = messages[index]["createDate"]
        indices = messages[index]["indices"]

        result.append({
            "role": role,
            "name": name,
            "content": content,
            "timestamp": timestamp,
            "indices": indices,
            "createDate": util.dateTimestamp(str(createDate))
        })

    return jsonify({"result":result}), 200

# 儲存對話記錄
# => 參數：{"timestamp":<timestamp>,role":<角色>,"content":<內容>}
# => 結果：{"result":{"id":<儲存的ID>}}
@app.route('/message', methods=['POST'])
def storeMessage(url = config.MongoAPI, databaseName = config.MenuDatabase, collectionName = config.MessageTable):
    
    database = service.createDatabase(url=url, name=databaseName)
    # collection = service.linkCollection(database=database, name="messages")
    # service.uniqueField(collection=collection, name="id")

    if request.is_json:
        json = request.json
        
        role = json.get('role')
        name = json.get('name')
        content = json.get('content')
        timestamp = json.get('timestamp')
        indices = json.get('indices')

        document = {
            "role": role, 
            "name": name,
            "content": content,
            "indices": indices,
            "timestamp": timestamp, 
            "createDate": datetime.now()
        }
        
        collection = service.linkCollection(database=database, name=collectionName)
        result = service.insertDocument(collection=collection, document=document)
        insertedId, code = result.inserted_id, 200

    database.client.close()
    return jsonify({"result":{"id": str(insertedId)}}), code

# 更新對話記錄
# => 參數：{"timestamp":<時間戳記>,"role":<角色>,"content":<內容>}
# => 結果：{"result":{"count":<更新的筆數>}}
@app.route('/message', methods=['PUT'])
def updateMessage(url = config.MongoAPI, databaseName = config.MenuDatabase, collectionName = config.MessageTable):

    database = service.createDatabase(url=url, name=databaseName)
    collection = service.linkCollection(database=database, name=collectionName)
    
    if request.is_json:

        json = request.json
        role = json.get('role')
        timestamp = json.get('timestamp')

        query = {
            "role": role,
            "timestamp": timestamp, 
        }

        document = {
            "content": json.get('content'),
        }

        result = service.updateDocument(collection=collection, query=query, document=document)
        count, code = result.modified_count, 200
        database.client.close()

        return jsonify({"result":{"count": count}}), code

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=54321, debug=True)
