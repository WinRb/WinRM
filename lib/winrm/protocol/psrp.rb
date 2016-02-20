# -*- encoding: utf-8 -*-
#
# Copyright 2016 Matt Wrock <matt@mattwrock.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module WinRM
  module Protocol
    class PSRP < Base
      def open
        logger.debug("[WinRM] opening remote shell on #{@endpoint}")

        shell_id = SecureRandom.uuid.to_s.upcase
        @session_id = SecureRandom.uuid.to_s.upcase

        session_capabilities = psrp_message(1, shell_id, nil, '00010002', %{<Obj RefId="0"><MS><Version N="protocolversion">2.3</Version><Version N="PSVersion">2.0</Version><Version N="SerializationVersion">1.1.0.1</Version></MS></Obj>})
        runspace_init = psrp_message(2, shell_id, nil, '00010004', %{<Obj RefId="0"><MS><I32 N="MinRunspaces">1</I32><I32 N="MaxRunspaces">1</I32><Obj N="PSThreadOptions" RefId="1"><TN RefId="0"><T>System.Management.Automation.Runspaces.PSThreadOptions</T><T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN><ToString>Default</ToString><I32>0</I32></Obj><Obj N="ApartmentState" RefId="2"><TN RefId="1"><T>System.Threading.ApartmentState</T><T>System.Enum</T><T>System.ValueType</T><T>System.Object</T></TN><ToString>Unknown</ToString><I32>2</I32></Obj><Obj N="ApplicationArguments" RefId="3"><TN RefId="2"><T>System.Management.Automation.PSPrimitiveDictionary</T><T>System.Collections.Hashtable</T><T>System.Object</T></TN><DCT><En><S N="Key">PSVersionTable</S><Obj N="Value" RefId="4"><TNRef RefId="2" /><DCT><En><S N="Key">PSVersion</S><Version N="Value">5.0.11082.1000</Version></En><En><S N="Key">PSCompatibleVersions</S><Obj N="Value" RefId="5"><TN RefId="3"><T>System.Version[]</T><T>System.Array</T><T>System.Object</T></TN><LST><Version>1.0</Version><Version>2.0</Version><Version>3.0</Version><Version>4.0</Version><Version>5.0.11082.1000</Version></LST></Obj></En><En><S N="Key">CLRVersion</S><Version N="Value">4.0.30319.42000</Version></En><En><S N="Key">BuildVersion</S><Version N="Value">10.0.11082.1000</Version></En><En><S N="Key">WSManStackVersion</S><Version N="Value">3.0</Version></En><En><S N="Key">PSRemotingProtocolVersion</S><Version N="Value">2.3</Version></En><En><S N="Key">SerializationVersion</S><Version N="Value">1.1.0.1</Version></En></DCT></Obj></En></DCT></Obj><Obj N="HostInfo" RefId="6"><MS><Obj N="_hostDefaultData" RefId="7"><MS><Obj N="data" RefId="8"><TN RefId="4"><T>System.Collections.Hashtable</T><T>System.Object</T></TN><DCT><En><I32 N="Key">9</I32><Obj N="Value" RefId="9"><MS><S N="T">System.String</S><S N="V">C:\dev\kitchen-vagrant</S></MS></Obj></En><En><I32 N="Key">8</I32><Obj N="Value" RefId="10"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="11"><MS><I32 N="width">199</I32><I32 N="height">52</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">7</I32><Obj N="Value" RefId="12"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="13"><MS><I32 N="width">80</I32><I32 N="height">52</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">6</I32><Obj N="Value" RefId="14"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="15"><MS><I32 N="width">80</I32><I32 N="height">25</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">5</I32><Obj N="Value" RefId="16"><MS><S N="T">System.Management.Automation.Host.Size</S><Obj N="V" RefId="17"><MS><I32 N="width">80</I32><I32 N="height">9999</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">4</I32><Obj N="Value" RefId="18"><MS><S N="T">System.Int32</S><I32 N="V">25</I32></MS></Obj></En><En><I32 N="Key">3</I32><Obj N="Value" RefId="19"><MS><S N="T">System.Management.Automation.Host.Coordinates</S><Obj N="V" RefId="20"><MS><I32 N="x">0</I32><I32 N="y">9974</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">2</I32><Obj N="Value" RefId="21"><MS><S N="T">System.Management.Automation.Host.Coordinates</S><Obj N="V" RefId="22"><MS><I32 N="x">0</I32><I32 N="y">9998</I32></MS></Obj></MS></Obj></En><En><I32 N="Key">1</I32><Obj N="Value" RefId="23"><MS><S N="T">System.ConsoleColor</S><I32 N="V">0</I32></MS></Obj></En><En><I32 N="Key">0</I32><Obj N="Value" RefId="24"><MS><S N="T">System.ConsoleColor</S><I32 N="V">7</I32></MS></Obj></En></DCT></Obj></MS></Obj><B N="_isHostNull">false</B><B N="_isHostUINull">false</B><B N="_isHostRawUINull">false</B><B N="_useRunspaceHost">false</B></MS></Obj></MS></Obj>})
        shell_body = shell_body_streams
        shell_body["creationXml"] = encode_bytes(session_capabilities + runspace_init)
        shell_body[:attributes!] = {
          "creationXml" => {
            "xmlns" => "http://schemas.microsoft.com/powershell"
          }
        }
  
        envelope = write_envelope(action_create, create_option_set) do |body|
          body.tag!(
            "#{NS_WIN_SHELL}:Shell",
            {
              "ShellId" => shell_id
            }
          ) { |s| s << Gyoku.xml(shell_body) }
        end

        resp_doc = send_message(envelope)
        shell_id = REXML::XPath.first(resp_doc, "//*[@Name='ShellId']").text

        keep_alive(shell_id)
        
        logger.debug("[WinRM] remote shell #{shell_id} is open on #{@endpoint}")

        shell_id
      end

      protected

      def resource_uri
        {"#{NS_WSMAN_DMTF}:ResourceURI" => 'http://schemas.microsoft.com/powershell/Microsoft.PowerShell',
          :attributes! => {"#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => true}}}
      end

      def input_streams
        ['stdin', 'pr']
      end

      def output_streams
        ['stdout']
      end 

      private

      def keep_alive(shell_id)
        h_opts = { "#{NS_WSMAN_DMTF}:OptionSet" => { "#{NS_WSMAN_DMTF}:Option" => "TRUE",
          :attributes! => {"#{NS_WSMAN_DMTF}:Option" => {'Name' => 'WSMAN_CMDSHELL_OPTION_KEEPALIVE'}}}}
        body = { "#{NS_WIN_SHELL}:DesiredStream" => 'stdout' }
        builder = Builder::XmlMarkup.new
        builder.instruct!(:xml, :encoding => 'UTF-8')
        builder.tag! :env, :Envelope, namespaces do |env|
          env.tag!(:env, :Header) { |h| h << Gyoku.xml(merge_headers(header,resource_uri_cmd,action_receive,h_opts,selector_shell_id(shell_id))) }
          env.tag! :env, :Body do |env_body|
            env_body.tag!("#{NS_WIN_SHELL}:Receive") { |cl| cl << Gyoku.xml(body) }
          end
        end

        resp_doc = send_message(builder.target!)
      end

      def create_option_set
        @option_set ||= {
          "#{NS_WSMAN_DMTF}:OptionSet" => {
            "#{NS_WSMAN_DMTF}:Option" => 2.3,
            :attributes! => {
              "#{NS_WSMAN_DMTF}:Option" => {
                'Name' => 'protocolversion',
                'MustComply' => 'true'
              }
            }
          },
          :attributes! => {
            "#{NS_WSMAN_DMTF}:OptionSet" => {
              'env:mustUnderstand' => 'true'
            }
          }
        }
      end
    end
  end
end
