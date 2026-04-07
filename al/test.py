import boto3

# Если AWS S3, endpoint_url не нужен. Если свой S3 - раскомментируйте и впишите.
s3 = boto3.client('s3', 
    aws_access_key_id='ВАШ_LOGIN', 
    aws_secret_access_key='ВАШ_PASSWORD',
    # endpoint_url='https://s3.yandexcloud.net', 
    region_name='us-east-1' # или ваш регион
)

# Пытаемся записать тестовый файл
s3.put_object(Bucket='имя-вашего-бакета', Key='test.txt', Body=b'Hello S3!')
print("Успех!")
-----
{
  "endpoint_url": "https://minio.example.local",
  "region_name": "us-east-1"
}
