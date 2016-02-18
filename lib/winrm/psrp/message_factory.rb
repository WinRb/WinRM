# encoding: UTF-8
#
# Copyright 2016 Shawn Neal <sneal@sneal.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module WinRM
  module PSRP
    class MessageFactory
      class << self
        # Creates a new session capability PSRP message.
        # @param id [Fixnum] The incrementing fragment id.
        # @param shell_id [String] The UUID of the remote shell/runspace pool.
        def session_capability_message(id, shell_id)
          Message.new(id, shell_id, nil, 0x00010002, %{<Obj RefId="0"><MS><Version N="protocolversion">2.3</Version><Version N="PSVersion">2.0</Version><Version N="SerializationVersion">1.1.0.1</Version></MS></Obj>})
        end

        # Creates a new init runspace pool PSRP message.
        # @param id [Fixnum] The incrementing fragment id.
        # @param shell_id [String] The UUID of the remote shell/runspace pool.
        def init_runspace_pool_message(id, shell_id)
          Message.new(id, shell_id, nil, 0x00010004, %{<Obj RefId="0"><MS><I32 N="MinRunspaces">1</I32><I32 N="MaxRunspaces">1</I32><Obj N="PSThreadOptions" RefId="1"><TN RefId="0"><T>System.Management.Automation.Runspaces.PSThreadOptions</T><T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN><ToString>Default</ToString><I32>0</I32></Obj><Obj N="ApartmentState" RefId="2"><TN RefId="1"><T>System.Threading.ApartmentState</T><T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN><ToString>Unknown</ToString><I32>2</I32></Obj><Obj N="ApplicationArguments" RefId="3"><TN RefId="2"><T>System.Management.Automation.PSPrimitiveDictionary</T><T>System.Collections.Hashtable</T><T>System.Object</T></TN><DCT><En><S N="Key">PSVersionTable</S><Obj N="Value" RefId="4"><TNRef RefId="2" /><DCT><En><S N="Key">PSVersion</S><Version N="Value">5.0.11082.1000</Version></En><En><S N="Key">PSCompatibleVersions</S><Obj N="Value" RefId="5"><TN RefId="3"><T>System.Version[]</T><T>System.Array</T><T>System.Object</T></TN><LST><Version>1.0</Version><Version>2.0</Version><Version>3.0</Version><Version>4.0</Version><Version>5.0.11082.1000</Version></LST></Obj></En><En><S N="Key">CLRVersion</S><Version N="Value">4.0.30319.42000</Version></En><En><S N="Key">BuildVersion</S><Version N="Value">10.0.11082.1000</Version></En><En><S N="Key">WSManStackVersion</S><Version N="Value">3.0</Version></En><En><S N="Key">PSRemotingProtocolVersion</S><Version N="Value">2.3</Version></En><En><S N="Key">SerializationVersion</S><Version N="Value">1.1.0.1</Version></En></DCT></Obj></En></DCT></Obj><Obj N="HostInfo" RefId="6"><MS><Obj N="_hostDefaultData" RefId="7"><MS><Obj N="data" RefId="8"><TN RefId="4"><T>System.Collections.Hashtable</T><T>System.Object</T></TN><DCT><En><I32 N="Key">9</I32><Obj N="Value" RefId="9"><MS><S N="T">System.String</S><S N="V">C:\dev\kitchen-vagrant</S></MS></Obj></En><En><I32 N="Key">8</I32><Obj N="Value" RefId="10"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="11"><MS><I32 N="width">199</I32><I32 N="height">52</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">7</I32><Obj N="Value" RefId="12"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="13"><MS><I32 N="width">80</I32><I32 N="height">52</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">6</I32><Obj N="Value" RefId="14"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="15"><MS><I32 N="width">80</I32><I32 N="height">25</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">5</I32><Obj N="Value" RefId="16"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="17"><MS><I32 N="width">80</I32><I32 N="height">9999</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">4</I32><Obj N="Value" RefId="18"><MS><S N="T">System.Int32</S><I32 N="V">25</I32></MS></Obj></En><En><I32 N="Key">3</I32><Obj N="Value" RefId="19"><MS><S N="T">System.Management.Automation.Host.Coordinates</S><Obj N="V" RefId="20"><MS><I32 N="x">0</I32><I32 N="y">9974</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">2</I32><Obj N="Value" RefId="21"><MS><S N="T">System.Management.Automation.Host.Coordinates</S><Obj N="V" RefId="22"><MS><I32 N="x">0</I32><I32 N="y">9998</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">1</I32><Obj N="Value" RefId="23"><MS><S N="T">System.ConsoleColor</S><I32 N="V">0</I32></MS></Obj></En><En><I32 N="Key">0</I32><Obj N="Value" RefId="24"><MS><S N="T">System.ConsoleColor</S><I32 N="V">7</I32></MS></Obj></En></DCT></Obj></MS></Obj><B N="_isHostNull">false</B><B N="_isHostUINull">false</B><B N="_isHostRawUINull">false</B><B N="_useRunspaceHost">false</B></MS></Obj></MS></Obj>})
        end

        # Creates a new PSRP message that creates pipline to execute a command.
        # @param id [Fixnum] The incrementing fragment id.
        # @param shell_id [String] The UUID of the remote shell/runspace pool.
        # @param command_id [String] The UUID to correlate the command/pipeline
        # response.
        # @param command [String] The command passed to Invoke-Expression.
        def create_pipeline_message(id, shell_id, command_id, command)
          Message.new(id, shell_id, command_id, 0x00021006, %{<Obj RefId="0"><MS><Obj N="PowerShell" RefId="1"><MS><Obj N="Cmds" RefId="2"><TN RefId="0"><T>System.Collections.Generic.List`1[[System.Management.Automation.PSObject, System.Management.Automation, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35]]</T><T>System.Object</T></TN><LST><Obj RefId="3"><MS><S N="Cmd">Invoke-expression</S><B N="IsScript">false</B><Nil N="UseLocalScope" /><Obj N="MergeMyResult" RefId="4"><TN RefId="1"><T>System.Management.Automation.Runspaces.PipelineResultTypes</T><T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeToResult" RefId="5"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergePreviousResults" RefId="6"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeError" RefId="7"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeWarning" RefId="8"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeVerbose" RefId="9"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeDebug" RefId="10"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="Args" RefId="11"><TNRef RefId="0" /><LST><Obj RefId="12"><MS><S N="N">-Command</S><Nil N="V" /></MS></Obj><Obj RefId="13"><MS><Nil N="N" /><S N="V">#{command}</S></MS></Obj></LST></Obj></MS></Obj><Obj RefId="14"><MS><S N="Cmd">Out-string</S><B N="IsScript">false</B><Nil N="UseLocalScope" /><Obj N="MergeMyResult" RefId="15"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeToResult" RefId="16"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergePreviousResults" RefId="17"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeError" RefId="18"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeWarning" RefId="19"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeVerbose" RefId="20"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="MergeDebug" RefId="21"><TNRef RefId="1" /><ToString>None</ToString><I32>0</I32></Obj><Obj N="Args" RefId="22"><TNRef RefId="0" /><LST /></Obj></MS></Obj></LST></Obj><B N="IsNested">false</B><Nil N="History" /><B N="RedirectShellErrorOutputPipe">true</B></MS></Obj><B N="NoInput">true</B><Obj N="ApartmentState" RefId="23"><TN RefId="2"><T>System.Threading.ApartmentState</T><T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN><ToString>Unknown</ToString><I32>2</I32></Obj><Obj N="RemoteStreamOptions" RefId="24"><TN RefId="3"><T>System.Management.Automation.RemoteStreamOptions</T><T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN><ToString>0</ToString><I32>0</I32></Obj><B N="AddToHistory">true</B><Obj N="HostInfo" RefId="25"><MS><B N="_isHostNull">true</B><B N="_isHostUINull">true</B><B N="_isHostRawUINull">true</B><B N="_useRunspaceHost">true</B></MS></Obj><B N="IsNested">false</B></MS></Obj>})
        end
      end
    end
  end
end
