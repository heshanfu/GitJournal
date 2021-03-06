import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'githost.dart';

class GitLab implements GitHost {
  static const _clientID =
      "faf33c3716faf05bfb701b1b31e36c83a23c3ec2d7161f4ff00fba2275524d09";

  var _platform = const MethodChannel('gitjournal.io/git');
  var _accessCode = "";
  var _stateOAuth = "";

  @override
  void init(Function callback) {
    Future _handleMessages(MethodCall call) async {
      if (call.method != "onURL") {
        print("GitLab Unknown Call: " + call.method);
        return;
      }

      print("GitLab: Called onUrl with " + call.arguments.toString());

      String url = call.arguments["URL"];
      var queryParamters = url.substring(url.indexOf('#') + 1);
      var map = Uri.splitQueryString(queryParamters);

      var state = map['state'];
      if (state != _stateOAuth) {
        print("GitLab: OAuth State incorrect");
        print("Required State: " + _stateOAuth);
        print("Actual State: " + state);
        callback(GitHostException.OAuthFailed);
        return;
      }

      _accessCode = map['access_token'];
      if (_accessCode == null) {
        callback(GitHostException.OAuthFailed);
        return;
      }

      callback(null);
    }

    _platform.setMethodCallHandler(_handleMessages);
    print("GitLab: Installed Handler");
  }

  @override
  Future launchOAuthScreen() async {
    _stateOAuth = _randomString(10);

    var url =
        "https://gitlab.com/oauth/authorize?client_id=$_clientID&response_type=token&state=$_stateOAuth&redirect_uri=gitjournal://login.oauth2";
    return launch(url);
  }

  @override
  Future<List<GitRepo>> listRepos() async {
    if (_accessCode.isEmpty) {
      throw GitHostException.MissingAccessCode;
    }

    // FIXME: pagination!
    var url =
        "https://gitlab.com/api/v4/projects?simple=true&membership=true&order_by=last_activity_at&access_token=$_accessCode";

    var response = await http.get(url);
    if (response.statusCode != 200) {
      print("GitLab listRepos: Invalid response " +
          response.statusCode.toString() +
          ": " +
          response.body);
      return null;
    }

    List<dynamic> list = jsonDecode(response.body);
    var repos = List<GitRepo>();
    list.forEach((dynamic d) {
      var map = Map<String, dynamic>.from(d);
      var repo = _repoFromJson(map);
      repos.add(repo);
    });

    // FIXME: Sort these based on some criteria
    return repos;
  }

  @override
  Future<GitRepo> createRepo(String name) async {
    if (_accessCode.isEmpty) {
      throw GitHostException.MissingAccessCode;
    }

    var url = "https://gitlab.com/api/v4/projects?access_token=$_accessCode";
    var data = <String, dynamic>{
      'name': name,
      'visibility': 'private',
    };

    var headers = {
      HttpHeaders.contentTypeHeader: "application/json",
    };

    var response =
        await http.post(url, headers: headers, body: json.encode(data));
    if (response.statusCode != 201) {
      print("GitLab createRepo: Invalid response " +
          response.statusCode.toString() +
          ": " +
          response.body);

      if (response.statusCode == 400) {
        if (response.body.contains("has already been taken")) {
          throw GitHostException.RepoExists;
        }
      }

      throw GitHostException.CreateRepoFailed;
    }

    print("GitLab createRepo: " + response.body);
    Map<String, dynamic> map = json.decode(response.body);
    return _repoFromJson(map);
  }

  @override
  Future<GitRepo> getRepo(String name) async {
    if (_accessCode.isEmpty) {
      throw GitHostException.MissingAccessCode;
    }

    var userInfo = await getUserInfo();
    var repo = userInfo.username + '%2F' + name;
    var url =
        "https://gitlab.com/api/v4/projects/$repo?access_token=$_accessCode";

    var response = await http.get(url);
    if (response.statusCode != 200) {
      print("GitLab getRepo: Invalid response " +
          response.statusCode.toString() +
          ": " +
          response.body);

      throw GitHostException.GetRepoFailed;
    }

    print("GitLab getRepo: " + response.body);
    Map<String, dynamic> map = json.decode(response.body);
    return _repoFromJson(map);
  }

  @override
  Future addDeployKey(String sshPublicKey, String repo) async {
    if (_accessCode.isEmpty) {
      throw GitHostException.MissingAccessCode;
    }

    repo = repo.replaceAll('/', '%2F');
    var url =
        "https://gitlab.com/api/v4/projects/$repo/deploy_keys?access_token=$_accessCode";

    var data = {
      'title': "GitJournal",
      'key': sshPublicKey,
      'can_push': true,
    };

    var headers = {
      HttpHeaders.contentTypeHeader: "application/json",
    };

    var response =
        await http.post(url, headers: headers, body: json.encode(data));
    if (response.statusCode != 201) {
      print("GitLab addDeployKey: Invalid response " +
          response.statusCode.toString() +
          ": " +
          response.body);
      throw GitHostException.DeployKeyFailed;
    }

    print("GitLab addDeployKey: " + response.body);
    return json.decode(response.body);
  }

  GitRepo _repoFromJson(Map<String, dynamic> parsedJson) {
    return GitRepo(
      fullName: parsedJson['path_with_namespace'],
      cloneUrl: parsedJson['ssh_url_to_repo'],
    );
  }

  @override
  Future<UserInfo> getUserInfo() async {
    if (_accessCode.isEmpty) {
      throw GitHostException.MissingAccessCode;
    }

    var url = "https://gitlab.com/api/v4/user?access_token=$_accessCode";

    var response = await http.get(url);
    if (response.statusCode != 200) {
      print("GitLab getUserInfo: Invalid response " +
          response.statusCode.toString() +
          ": " +
          response.body);
      return null;
    }

    Map<String, dynamic> map = jsonDecode(response.body);
    if (map == null || map.isEmpty) {
      print("GitLab getUserInfo: jsonDecode Failed " +
          response.statusCode.toString() +
          ": " +
          response.body);
      return null;
    }

    return UserInfo(
      name: map['name'],
      email: map['email'],
      username: map['username'],
    );
  }
}

String _randomString(int length) {
  var rand = Random();
  var codeUnits = List.generate(length, (index) {
    return rand.nextInt(33) + 89;
  });

  return String.fromCharCodes(codeUnits);
}
