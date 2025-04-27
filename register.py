import json
import os
import uuid
import time
import boto3
from datetime import datetime

# Configuración optimizada
dynamodb = boto3.resource(
    'dynamodb',
    config=boto3.session.Config(
        max_pool_connections=25,  # Ajuste para conexiones concurrentes
        connect_timeout=2,        # Timeout más corto
        read_timeout=2
    )
)
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

def handler(event, context):
    start_time = time.time()
    
    try:
        # Validar tamaño del payload (max 10KB)
        if len(event.get('body', '')) > 10240:
            return {
                'statusCode': 413,
                'body': json.dumps({'error': 'Payload too large'})
            }
        
        body = json.loads(event['body'])
        
        # Validación mínima con mensajes compactos
        required_fields = {'name': str, 'email': str}
        errors = {}
        for field, field_type in required_fields.items():
            if field not in body or not isinstance(body[field], field_type):
                errors[field] = 'required'
        
        if errors:
            return {
                'statusCode': 400,
                'body': json.dumps({'errors': errors})
            }
        
        # Item optimizado para DynamoDB
        item = {
            'id': str(uuid.uuid4()),
            'name': body['name'][:100],  # Campo abreviado
            'email': body['email'][:100], # Campo abreviado
            'timestamp': int(time.time()),   # Timestamp numérico
            'datetime': datetime.utcnow().strftime('%Y-%m-%d')  # Fecha para posibles queries
        }
        
        # Campos opcionales con nombres cortos
        if 'phone' in body:
            item['p'] = body['phone'][:20]
        
        # Escritura condicional para evitar duplicados
        table.put_item(
            Item=item,
            ConditionExpression='attribute_not_exists(e)'
        )
        
        execution_time = (time.time() - start_time) * 1000
        
        return {
            'statusCode': 201,
            'body': json.dumps({
                'id': item['id'],
                't': round(execution_time, 2)  # Tiempo de ejecución
            })
        }
        
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        return {
            'statusCode': 409,
            'body': json.dumps({'error': 'Email already exists'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }