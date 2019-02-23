/*
 * Copyright 2017-2018 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package framework

import (
	"encoding/json"
	"io/ioutil"
)

//Frameworks All frameworks supported and maintained by dlaas
type Frameworks struct {
	Frameworks map[string]*DetailList
}

//DetailList list of versions for a framework
type DetailList struct {
	Versions []*Details
}

//Details Specific details for a framework version
type Details struct {
	Version   string
	External  bool
	Build     string
	PrevBuild string
}

func readFile(location string) ([]byte, error) {
	fileData, err := ioutil.ReadFile(location)
	if err != nil {
		return []byte(""), err
	}
	return fileData, nil
}

//GetFrameworks returns the frameworks and their versions that are stored in the path to the learnerConfig
func GetFrameworks(learnerConfigPath string) (Frameworks, error) {
	var frameworks Frameworks
	fileData, err := readFile(learnerConfigPath)
	if err != nil {
		return frameworks, err
	}
	err = json.Unmarshal(fileData, &frameworks)
	if err != nil {
		return frameworks, err
	}

	return frameworks, nil
}

//GetImageBuildTagForFramework Returns the latest build tag for a specified framework and version
func GetImageBuildTagForFramework(fwName, fwVersion, learnerConfigPath string) string {
	frameworks, err := GetFrameworks(learnerConfigPath)
	if err != nil {
		return ""
	}

	frameworkVersions := frameworks.Frameworks[fwName].Versions

	for _, frameworkVersion := range frameworkVersions {
		if frameworkVersion.Version == fwVersion {
			return frameworkVersion.Build
		}
	}

	return ""
}

//CheckIfFrameworkExists Checks if the specified framework exists
func CheckIfFrameworkExists(fwName, fwVersion, learnerConfigPath string) (bool, error) {
	frameworks, err := GetFrameworks(learnerConfigPath)
	if err != nil {
		return false, err
	}

	frameworkType := frameworks.Frameworks[fwName]
	if frameworkType == nil {
		return false, nil
	}
	frameworkVersions := frameworkType.Versions

	for _, frameworkVersion := range frameworkVersions {
		if frameworkVersion.Version == fwVersion {
			return true, nil
		}
	}
	return false, nil
}
