# Copyright 2007 Wencheng Fang
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

package Mindmap::L10N::zh_cn;

use strict;
use base 'Mindmap::L10N::en_us';
use vars qw( %Lexicon );

# The following is the translation table.
%Lexicon = (
	'The Plugin to display category as a mindmap' => '心智图显示插件。',
    'Show blog name:' => '显示Blog名:',
    'Show blog\'s name in the mindmap' => '在心智图中显示Blog名',
    'Show version:' => '显示版本信息:',
    'Show the version information of this plugin in the mindmap' =>  '在心智图中显示插件的版本信息',
    'Show entry:' => '显示文章:',
    'Show entries of each category in the mindmap<br/>(Only categories would be drawn if not checked)'
    	=> '在心智图中显示每个类别的文章<br/>（如果关掉这个选项，只有类别会被显示）',
    'Font path:' => '字体路径:',
    'Color1:' => '颜色1:',
    'Color2:' => '颜色2:',
    'Color3:' => '颜色3:',
    'Color4:' => '颜色4:',
    'The Movable Type Plugin Mindmap' => '心智图显示插件',
    'version' => '版本',
    'Rebuild' => '重建',
    'Return' => '返回',
    'Config the 4 color used in the mindmap.' => '设定心智图中所使用的4种颜色。',
    'See mindmap' => '显示心智图',
);

1;