import json


def make_apigw_event(
    method="GET",
    path="/orders",
    body=None,
    path_params=None,
    query_params=None,
    user_id="user-test-123",
):
    return {
        "httpMethod": method,
        "path": path,
        "body": body if isinstance(body, str) else (None if body is None else json.dumps(body)),
        "pathParameters": path_params,
        "queryStringParameters": query_params,
        "headers": {"Content-Type": "application/json"},
        "requestContext": {
            "authorizer": {
                "claims": (
                    {
                        "sub": user_id,
                        "email": f"{user_id}@example.com",
                    }
                    if user_id
                    else {}
                )
            }
        },
    }
