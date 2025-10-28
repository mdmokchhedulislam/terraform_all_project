


resource "aws_apigatewayv2_api" "my_api" {
  name          = "my-microservice-api"
  protocol_type = "HTTP"
}


resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.my_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "httpbin" {
  api_id             = aws_apigatewayv2_api.my_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "https://httpbin.org/get"
  integration_method = "GET"
  payload_format_version = "1.0"
}


resource "aws_apigatewayv2_route" "test_route" {
  api_id    = aws_apigatewayv2_api.my_api.id
  route_key = "GET /test"
  target    = "integrations/${aws_apigatewayv2_integration.httpbin.id}"
}
