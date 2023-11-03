# Databricks notebook source
s3_bucket_name = "aweaver-il-central-1"
region_name = "il-central-1"

# COMMAND ----------

display(dbutils.fs.ls("/databricks-datasets/wine-quality/"))

# COMMAND ----------

df = spark.read.csv("dbfs:/databricks-datasets/wine-quality/winequality-red.csv", header=True, sep=";")
display(df)

# COMMAND ----------

# MAGIC %sh
# MAGIC dig s3.il-central-1.amazonaws.com 

# COMMAND ----------

import boto3

session = boto3.Session()

s3_client = session.client(
service_name='s3',
region_name=region_name,
)

s3_client.list_objects(Bucket=s3_bucket_name)

# COMMAND ----------

spark.conf.set(f"fs.s3a.bucket.{s3_bucket_name}.endpoint", f"https://s3.{region_name}.amazonaws.com")
#spark.conf.set(f"fs.s3a.bucket.{s3_bucket_name}.endpoint", "https://bucket.vpce-*************.s3.{region_name}.vpce.amazonaws.com")
spark.conf.set("fs.s3a.endpoint.region", region_name)

# COMMAND ----------

dbutils.fs.ls(f"s3a://{s3_bucket_name}")

# COMMAND ----------

df = spark.read.csv(f"s3a://{s3_bucket_name}/wine_quality/winequality-red.csv", header=True, sep=";")
display(df)

# COMMAND ----------

# MAGIC %sql
# MAGIC SHOW CATALOGS

# COMMAND ----------

# MAGIC %sql
# MAGIC SHOW SCHEMAS IN main