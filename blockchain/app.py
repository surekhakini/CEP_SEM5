
from flask import Flask, request, jsonify
from blockchain import blockchain_service as service

app = Flask(__name__)


def error_response(error, status_code=400):
    return jsonify({"success": False, "error": str(error)}), status_code


def required(data, *fields):
    missing = [
        field for field in fields
        if field not in data or data[field] is None or data[field] == ""
    ]
    if missing:
        raise ValueError("Missing required fields: " + ", ".join(missing))


@app.get("/api/health")
def health():
    try:
        return jsonify({
            "success": True,
            "blockchainConnected": service.web3.is_connected(),
            "chainId": service.web3.eth.chain_id,
            "contractAddress": service.contract.address
        })
    except Exception as error:
        return error_response(error, 503)


@app.post("/api/batches")
def register_batch():
    data = request.get_json(silent=True) or {}

    try:
        required(
            data, "privateKey", "batchId", "medicineName",
            "batchNumber", "expiryTimestamp", "quantity", "sealId"
        )

        result = service.register_batch(
            data["privateKey"],
            data["batchId"],
            data["medicineName"],
            data["batchNumber"],
            int(data["expiryTimestamp"]),
            int(data["quantity"]),
            data["sealId"]
        )

        return jsonify({"success": True, "result": result}), 201
    except ValueError as error:
        return error_response(error)
    except Exception as error:
        return error_response(error)


@app.post("/api/participants/authorize")
def authorize_participant():
    data = request.get_json(silent=True) or {}

    try:
        required(data, "privateKey", "account")

        account = service.web3.eth.account.from_key(data["privateKey"])

        if account.address.lower() != service.contract.functions.owner().call().lower():
            return jsonify({
                "success": False,
                "error": "Only the contract owner can authorize participants"
            }), 403

        target = service.web3.to_checksum_address(data["account"])

        function = service.contract.functions.authorizeParticipant(target)
        result = service._send_transaction(function, account)

        return jsonify({"success": True, "result": result}), 200

    except ValueError as error:
        return error_response(error)
    except Exception as error:
        return error_response(error)



@app.post("/api/batches/<batch_id>/transfers")
def transfer_batch(batch_id):
    data = request.get_json(silent=True) or {}

    try:
        required(data, "privateKey", "receiver", "newSealId")

        result = service.transfer_batch(
            data["privateKey"],
            batch_id,
            data["receiver"],
            data["newSealId"]
        )

        return jsonify({"success": True, "result": result}), 200
    except ValueError as error:
        return error_response(error)
    except Exception as error:
        return error_response(error)


@app.post("/api/batches/<batch_id>/inspections")
def inspect_batch(batch_id):
    data = request.get_json(silent=True) or {}

    try:
        required(data, "privateKey", "notes", "newSealId")

        result = service.inspect_batch(
            data["privateKey"],
            batch_id,
            data["notes"],
            data["newSealId"]
        )

        return jsonify({"success": True, "result": result}), 200
    except ValueError as error:
        return error_response(error)
    except Exception as error:
        return error_response(error)


@app.get("/api/batches/<batch_id>")
def get_batch(batch_id):
    try:
        batch = service.get_batch(batch_id)
        return jsonify({"success": True, "batch": batch})
    except Exception as error:
        return error_response(error, 404)


@app.get("/api/batches/<batch_id>/history")
def get_batch_history(batch_id):
    try:
        history = service.get_batch_history(batch_id)
        return jsonify({"success": True, "history": history})
    except Exception as error:
        return error_response(error, 404)


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=False)
