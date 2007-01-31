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

package Mindmap::L10N::ja;

use strict;
use base 'Mindmap::L10N::en_us';
use vars qw( %Lexicon );

# The following is the translation table.
%Lexicon = (
    'The Plugin to display category as a mindmap' => 'カテゴリをマインドマップで表示するプラグインです。',
    'Show blog name:' => 'ブログ名表示:',
    'Show blog\'s name in the mindmap' => 'ブログ名をマインドマップに表示する',
    'Show version:' => 'バージョン情報表示:',
    'Show the version information of this plugin in the mindmap' =>  'プラグインのバージョン情報をマインドマップに表示する',
    'Show entry:' => 'エントリー表示:',
    'Show entries of each category in the mindmap<br/>(Only categories would be drawn if not checked)'
    	=> 'カテゴリに属するエントリーをマインドマップに表示する<br/>（この設定がオフの場合、カテゴリのみが表示される）',
    'Font path:' => 'フォントパス:',
    'Color1:' => '色1:',
    'Color2:' => '色2:',
    'Color3:' => '色3:',
    'Color4:' => '色4:',
    'The Movable Type Plugin Mindmap' => 'マインドマッププラグイン',
    'version' => 'バージョン',
    'Rebuild' => '再構築',
    'Return' => '戻る',
    'Config the 4 color used in the mindmap.' => 'マインドマップに使われる４色を設定する。',
    'See mindmap' => 'マインドマップを表示',
);

1;