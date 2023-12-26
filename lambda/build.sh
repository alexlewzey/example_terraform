#!/bin/bash
if [ -r "python_lambda.zip" ]; then
    rm python_lambda.zip
    echo "deleted: python_lambda.zip"
fi
if [ -r "src" ]; then
    rm -rf src
    echo "deleted: src"
fi

pip install -r requirements.txt -t src
cp index.py src/
cd src || exit 1
zip -r ../python_lambda.zip ./*
