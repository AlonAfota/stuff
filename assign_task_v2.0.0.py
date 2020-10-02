#!/usr/bin/env python3

import subprocess
import textwrap
import shlex
import json
import os.path


class ApiClient:
    horizon_url = "http://localhost/api/1"
    auth_token = "3b9a95980c3b2fdc71012d1bff8bf078babda10a"

    def __init__(self, horizon_url=None, auth_token=None):
        """Represents REST API client.

        Arguments:
            horizon_url (str) - Horizon REST API url
            auth_token (str) - authenitcation token

        Examples:
            api_client = ApiClient(
                horizon_url = "http://localhost/api/1",
                auth_token = "3b9a95980c3b2fdc71012d1bff8bf078babda10a"
            )
        """
        self.horizon_url = horizon_url or self.horizon_url
        self.auth_token = auth_token or self.auth_token

    def post(self, url, data, headers=None, files=None):
        """Sends HTTP POST request to REST API.

        Arguments:
            url (str) - endpoint path of the collection
            data (dict) - {str: str, ...} key/value pairs
            headers (dict) - {str: str, ...} key/value pairs
            files (dict) - {str: str, ...} key/value pairs
        """
        data_ = {k: v for k, v in data.items() if v}

        headers_ = {
            "Authorization": "Token {}".format(self.auth_token),
            "Content-Type": "multipart/form-data"
        }

        if headers:
            headers_.update(headers)
        
        files_ = {}
        if files:
            files_.update(files)

        cmd = "curl -s -X POST {headers} {data} {files} {url}".format(
            headers=' '.join(['-H "{}: {}"'.format(k, v) for k, v in headers_.items()]),
            data=' '.join(['-F {}="{}"'.format(k, v) for k, v in data_.items()]),
            files=' '.join(['-F {}=@"{}"'.format(k, v) for k, v in files_.items()]),
            url=self.horizon_url + url
        )
        print("  Going to run cmd:")
        print("    {}".format(cmd.encode("unicode_escape").decode("utf-8")))

        rsp = subprocess.check_output(cmd, shell=True)
        res = json.loads(rsp, encoding='utf-8')
        return res


class Resource:
    api_client = None
    
    def __init__(self, api_client=None):
        self.api_client = api_client or self.api_client
    
    def save(self):
        raise NotImplementedError("Should be implemented in descendants ...")
    
    def to_dict(self):
        raise NotImplementedError("Should be implemented in descendants ...")
    
    def __str__(self):
        """Returns string representation of Resource instance.

        Returns:
            str
        """
        return json.dumps(self.to_dict())


class Probe(Resource):
    def __init__(self, system_id, api_client=None):
        """Represents probe entity.

        Attributes:
            system_id (str): system id, normally mac address with dash as separator
            api_client (obj): instance of ApiClient class

        Examples:
            Probe(system_id="00-00-00-00-00-00")
        """
        super().__init__(api_client=api_client)
        self.system_id = system_id
    
    def save(self):
        raise NotImplementedError("Will be implemented in future versions ...")

    def to_dict(self):
        """Returns dict representation of Probe instance.
        
        Returns:
            dict 
        """
        res = {
            'system_id': self.system_id
        }
        return res


class Task(Resource):
    def __init__(self, name, cmdline=None, script=None, package=None, api_client=None):
        """Represents task entity.
        
        Attributes:
            name (str): task name
            cmdline (str): task command line
            script (str): task script
            package (str): path to package file
            api_client (obj): instance of ApiClient class
        """
        super().__init__(api_client=api_client)

        self.id = None

        self.name = name
        self.cmdline = cmdline
        self.script = script
        self.package = package

        self.api_client = api_client or self.api_client

    def save(self):
        """Creates Task entity by sending POST request.
        
        You may check appearance of new Task entity in Horizon UI:
            https://horizon-url/admin/tasks/task/
        
        Returns:
            self

        Raises:
            subprocess.CalledProcessError
        """
        data = {
            'name': self.name,
            'cmdline': self.cmdline,
            'script': self.script,
        }

        files = {}
        if self.package:
            files['package'] = self.package

        res = self.api_client.post('/tasks', data=self.to_dict(), files=files)
        self.id = res['id']

        return self

    def to_dict(self):
        """Returns dict representation of Task instance.

        Returns:
            dict 
        """
        data = {
            'id': self.id,
            'name': self.name,
            'cmdline': self.cmdline,
            'script': self.script
        }
        return data

    def __str__(self):
        """Returns string representation of Task instance.

        Returns:
            str 
        """
        res = self.to_dict()
        res['package'] = self.package
        return json.dumps(res)


class Assignment(Resource):
    def __init__(self, task_id, probe_id, api_client=None):
        """Represents task entity

        Attributes:
            task_id (str): task id
            probe_id (str): probe id
            api_client (obj): instance of ApiClient class
        """
        super().__init__(api_client=api_client)
        
        self.id = None
        
        self.task_id = task_id
        self.probe_id = probe_id
        self.api_client = api_client or self.api_client
        
    def save(self):
        """Creates Task entity by sending POST request.

        You may check appearance of new Task entity in Horizon UI:
            https://horizon-url/admin/tasks/task/
        
        Returns:
            self

        Raises:
            subprocess.CalledProcessError
        """

        res = self.api_client.post('/assignments', data=self.to_dict())
        self.id = res['id']

        return self

    def to_dict(self):
        """Returns dict representation of Assignment instance.
        
        Returns:
            dict 
        """
        data = {
            'id': self.id,
            'task_id': self.task_id,
            'probe_id': self.probe_id
        }
        return data


if __name__ == "__main__":
    Resource.api_client = ApiClient(
        horizon_url="http://localhost/api/1",
        auth_token="3b9a95980c3b2fdc71012d1bff8bf078babda10a"
    )
    
    probe = Probe(
        system_id="00-00-00-00-00-00"
    )
    
    print("Creating task:")
    task = Task(
        name="My Task 0001",
        cmdline="date",
        script=textwrap.dedent("""
            #!/bin/bash
            
            echo "It works!"
            
        """).lstrip(),
        package=os.path.realpath(__file__)
    )
    task.save()
    print("  Done:")
    print("    {}\n".format(task))
    
    print("Creating assignment:")
    assignment = Assignment(
        probe_id=probe.system_id,
        task_id=task.id
    )
    assignment.save()
    print("  Done:")
    print("    {}".format(assignment))    

