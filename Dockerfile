FROM python:3.7

WORKDIR /src/app

# add required code and notebook dirs
COPY requirements.txt ./
COPY setup.py ./
COPY setup.cfg ./
COPY README.rst ./
ADD dice_ml /src/app/dice_ml
ADD docs /src/app/docs

# build, install dice module
RUN pip install --upgrade pip
RUN pip install -e ./
#    pip install --no-cache-dir -r requirements.txt

# install jupyterlab
RUN pip install jupyterlab

CMD jupyter lab --ip=0.0.0.0 --port=8080 --no-browser \
    --LabApp.token='' \
    --LabApp.custom_display_url=https://${EAI_JOB_ID}.job.console.elementai.com \
    --LabApp.allow_remote_access=True \
    --LabApp.allow_origin='*' \
    --LabApp.disable_check_xsrf=True
