FROM python:2.7

RUN apt-get update && apt-get install -y python-pip

WORKDIR /app
ADD requirements.txt /app/
ADD setup.py /app/
ADD setup.cfg /app/
RUN pip install -r /app/requirements.txt

ADD mongodb /app/mongodb
ADD tests /app/tests

RUN cd /app \
  && rm -fr tests/mongodb/__pycache__ \
  && python setup.py test

  #&& rm -fr tests/mongodb/*.pyc \
CMD ["python", "/app/mongodb/main.py"]
ENTRYPOINT ["python", "/app/mongodb/main.py"]
