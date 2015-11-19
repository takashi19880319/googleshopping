# create_mall_entry_data.pl
# author:Takashi.Hashiguchi
# date:2015/10/1

#========== 改訂履歴 ==========
# 
#
########################################################
## Glober(本店)に登録されている商品をHFF楽天店,Yahoo!店の各モール店
## に登録する為のデータファイルを作成します。 
## 【入力ファイル】
## 本プログラムを実行する際に下記の入力ファイルが実行ディレクトリに存在している必要があります。
## ・goods.csv                                                             
## ・goods_supp.csv
## ・goods_img.csv
##    -本店に登録されている全商品のデータ。ecbeingよりダウンロード。
## 【ログファイル】
## ・create_google_shopping_data_yyyymmddhhmmss.log
##    -エラー情報などを出力
########################################################

#/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Encode;
use XML::Simple;
use Text::ParseWords;
use Text::CSV_XS;
use File::Path;

####################
##　ログファイル
####################
# ログファイルを格納するフォルダ名
my $output_log_dir="./../log";
# ログフォルダが存在しない場合は作成
unless (-d $output_log_dir) {
	if (!mkdir $output_log_dir) {
		&output_log("ERROR!!($!) create $output_log_dir failed\n");
		exit 1;
	}
}
#　ログファイル名
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
my $time_str = sprintf("%04d%02d%02d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my $log_file_name="$output_log_dir"."/"."create_mall_entry_data"."$time_str".".log";
# ログファイルのオープン
if(!open(LOG_FILE, "> $log_file_name")) {
	print "ERROR!!($!) $log_file_name open failed.\n";
	exit 1;
}

####################
##　入力ファイルの存在チェック
####################
#入力ファイル名
my $input_goods_file_name="goods.csv";
my $input_goods_supp_file_name="goods_supp.csv";
my $input_goods_img_file_name="goods_img.csv";
#入力ファイル配置ディレクトリのオープン
my $current_dir=Cwd::getcwd();
my $input_dir ="$current_dir"."/..";
if (!opendir(INPUT_DIR, "$input_dir")) {
	&output_log("ERROR!!($!) $input_dir open failed.");
	exit 1;
}
#　入力ファイルの有無チェック
my $goods_file_find=0;
my $goods_supp_file_find=0;
my $goods_img_file_find=0;
while (my $current_dir_file_name = readdir(INPUT_DIR)){
	if($current_dir_file_name eq $input_goods_file_name) {
		$goods_file_find=1;
		next;
	}
	elsif($current_dir_file_name eq $input_goods_supp_file_name) {
		$goods_supp_file_find=1;
		next;
	}
	elsif($current_dir_file_name eq $input_goods_img_file_name) {
		$goods_img_file_find=1;
		next;
	}
}
closedir(INPUT_DIR);
if (!$goods_file_find) {
	#goods.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_goods_file_name.\n");
}
if (!$goods_supp_file_find) {
	#goods_supp.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_goods_supp_file_name.\n");
}
if (!$goods_img_file_find) {
	#goods_img.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_goods_img_file_name.\n");
}

if (!$goods_file_find || !$goods_supp_file_find || !$goods_img_file_find) {
	exit 1;
}

####################
##　入力ファイルのオープン
####################
#CSVファイル用モジュールの初期化
my $input_goods_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_supp_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_img_csv = Text::CSV_XS->new({ binary => 1 });
#入力ファイルのオープン	
$input_goods_file_name="$input_dir"."/"."$input_goods_file_name";
my $input_goods_file_disc;
if (!open $input_goods_file_disc, "<", $input_goods_file_name) {
	&output_log("ERROR!!($!) $input_goods_file_name open failed.");
	exit 1;
}	
$input_goods_supp_file_name="$input_dir"."/"."$input_goods_supp_file_name";
my $input_goods_supp_file_disc;
if (!open $input_goods_supp_file_disc, "<", $input_goods_supp_file_name) {
	&output_log("ERROR!!($!) $input_goods_supp_file_name open failed.");
	exit 1;
}	
$input_goods_img_file_name="$input_dir"."/"."$input_goods_img_file_name";
my $input_goods_img_file_disc;
if (!open $input_goods_img_file_disc, "<", $input_goods_img_file_name) {
	&output_log("ERROR!!($!) $input_goods_img_file_name open failed.");
	exit 1;
}		

####################
##　出力ファイルのオープン
####################
#出力ディレクトリ
my $output_google_data_dir="../google_up_data";
my $output_criteo_data_dir="../criteo_up_data";
#出力ファイル名
my $output_google_file_name="$output_google_data_dir"."/"."google_goods.csv";
my $output_citeo_file_name="$output_criteo_data_dir"."/"."criteo_goods.csv";

#出力先ディレクトリの作成
unless(-d $output_google_data_dir) {
	# 存在しない場合はフォルダ作成
	if(!mkpath($output_google_data_dir)) {
		output_log("ERROR!!($!) $output_google_data_dir create failed.");
		exit 1;
	}
}
unless(-d $output_criteo_data_dir) {
	# 存在しない場合はフォルダ作成
	if(!mkpath($output_criteo_data_dir)) {
		output_log("ERROR!!($!) $output_criteo_data_dir create failed.");
		exit 1;
	}
}

#出力用CSVファイルモジュールの初期化
my $output_google_goods_csv = Text::CSV_XS->new({ binary => 1 });
my $output_criteo_goods_csv = Text::CSV_XS->new({ binary => 1 });

#出力ファイルのオープン
my $output_google_goods_file_disc;
if (!open $output_google_goods_file_disc, ">", $output_google_file_name) {
	&output_log("ERROR!!($!) $output_google_file_name open failed.");
	exit 1;
}
my $output_criteo_goods_file_disc;
if (!open $output_criteo_goods_file_disc, ">", $output_citeo_file_name) {
	&output_log("ERROR!!($!) $output_citeo_file_name open failed.");
	exit 1;
}

####################
## 各関数間に跨って使用するグローバル変数
####################
our $global_entry_goods_code="";
our $global_entry_goods_name="";
our $global_entry_goods_price=0;
our $global_entry_goods_category="";
our $global_entry_goods_color="";
our $global_entry_goods_size="";
our $stock_flag=0;
our $global_entry_goods_supp_info="";
our $global_entry_goods_img_info="";

#################################################################
##########################　main処理開始 ##########################　
#################################################################
&output_log("**********START**********\n");
# google用の出力CSVファイルに項目名を出力
 &add_google_goods_csv_name();
# criteo用の出力CSVファイルに項目名を出力
 &add_criteo_goods_csv_name();
# 商品データの作成
my $goods_line = $input_goods_csv->getline($input_goods_file_disc);
while($goods_line = $input_goods_csv->getline($input_goods_file_disc)){
	# goods.csvの商品情報を保持。コントロールカラムも保持する
	# [0]:商品コード [1]:カテゴリコード [3]:商品名 [7]:サイズ [8]:カラー [16]:販売価格
	$global_entry_goods_code=@$goods_line[0];
	$global_entry_goods_category=@$goods_line[1];
	$global_entry_goods_name=@$goods_line[2];
	$global_entry_goods_price=@$goods_line[3];
	$global_entry_goods_size=@$goods_line[5];
	$global_entry_goods_color=@$goods_line[6];
	my $goods_stock = @$goods_line[7];
	# 在庫が0のものは対象からはずす。
	if($goods_stock == 0){
		next;
	}elsif($goods_stock > 0){
		#通常商品の在庫があるもの
		$stock_flag =1;
	}elsif($goods_stock < 0){
		#予約商品
		$stock_flag =2;
	}
	##### goods_suppファイルの読み出し
	$global_entry_goods_supp_info="";
	my $goods_supp_find =0;
	seek $input_goods_supp_file_disc,0,0;
	my $goods_supp_line = $input_goods_supp_csv->getline($input_goods_supp_file_disc);
	while($goods_supp_line = $input_goods_supp_csv->getline($input_goods_supp_file_disc)){
		my $goods_supp_code_5 = @$goods_supp_line[0];
		# 商品コードが合致したらコードを保持する
		if (get_5code($global_entry_goods_code) eq get_5code($goods_supp_code_5)) {
			# goods_supp.csvの商品情報を保持(SKUのものは一つ目に合致した商品の情報を保持)
			##### goods_suppファイルの修正
			my $goods_supp = @$goods_supp_line[1];
			$goods_supp =~ s/<\/br>/<br \/>/g;
			$goods_supp =~ s/<\/font><\/a><\/li><\/ul>/<\/font><\/a>/g;
			my $before_str = "承ります。<br />詳しくはこちら。</font></span>";
			Encode::from_to( $before_str, 'utf8', 'shiftjis' );
			my $after_str = "承ります。<br />詳しくはこちら。</font></a></span>";
			Encode::from_to( $after_str, 'utf8', 'shiftjis' );
			$goods_supp =~ s/$before_str/$after_str/g;
			$global_entry_goods_supp_info = $goods_supp;
			$goods_supp_find =1;
			last;
		}
	}
	if(!$goods_supp_find){
		next;	
	}
	##### goods_specファイルの読み出し
	$global_entry_goods_img_info="";
	my $goods_img_find = 0;
	seek $input_goods_img_file_disc,0,0;
	my $goods_img_line=$input_goods_img_csv->getline($input_goods_img_file_disc);
	while($goods_img_line = $input_goods_img_csv->getline($input_goods_img_file_disc)){
		# 登録情報から商品コード読み出し
		if (get_9code($global_entry_goods_code) eq get_9code(@$goods_img_line[0])) {
			# 商品のスペック情報を保持する
			$global_entry_goods_img_info = "http://glober.jp/img/goods/1/"."@$goods_img_line[1]";
			$goods_img_find =1;
			last;
		}
	}
	if(!$goods_img_find){
		next;	
	}
	# google用データを追加
	&add_google_goods_data();
	# criteo用データを追加
#	&add_criteo_goods_data();
}

# 入力用CSVファイルモジュールの終了処理
$input_goods_csv->eof;
$input_goods_supp_csv->eof;
$input_goods_img_csv->eof;
# 出力用CSVファイルモジュールの終了処理
$output_google_goods_csv->eof;
$output_criteo_goods_csv->eof;

# 入力ファイルのクローズ
close $input_goods_file_disc;
close $input_goods_supp_file_disc;
close $input_goods_img_file_disc;
# 出力ファイルのクローズ
close $output_google_goods_file_disc;
close $output_criteo_goods_file_disc;

# 処理終了
output_log("Process is Success!!\n");
output_log("**********END**********\n");

close(LOG_FILE);
#################################################################
##########################　main処理終了 ##########################　
#################################################################

##############################
## google用csvファイルに項目名を追加
##############################
sub add_google_goods_csv_name {
	my @csv_google_goods_name=("id","商品名","商品説明","google 商品カテゴリ","商品リンク","商品画像リンク","状態","在庫状況","価格","ブランド","性別","年齢層","色","サイズ","商品グループid");
	my $csv_google_goods_name_num=@csv_google_goods_name;
	my $csv_google_goods_name_count=0;
	for my $csv_google_goods_name_str (@csv_google_goods_name) {
		Encode::from_to( $csv_google_goods_name_str, 'utf8', 'shiftjis' );
		$output_google_goods_csv->combine($csv_google_goods_name_str) or die $output_google_goods_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_google_goods_name_count >= $csv_google_goods_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_google_goods_file_disc $output_google_goods_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## criteo用csvファイルに項目名を追加
##############################
sub add_criteo_goods_csv_name {
	my @csv_criteo_goods_name=("id","商品名","商品説明","google 商品カテゴリ","商品リンク","商品画像リンク","状態","在庫状況","価格","ブランド","性別","年齢層","色","サイズ","商品グループid");
	my $csv_criteo_goods_name_num=@csv_criteo_goods_name;
	my $csv_criteo_goods_name_count=0;
	for my $csv_criteo_goods_name_str (@csv_criteo_goods_name) {
		Encode::from_to( $csv_criteo_goods_name_str, 'utf8', 'shiftjis' );
		$output_criteo_goods_csv->combine($csv_criteo_goods_name_str) or die $output_criteo_goods_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_criteo_goods_name_count >= $csv_criteo_goods_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_criteo_goods_file_disc $output_criteo_goods_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## 楽天用item.CSVファイルにデータを追加
##############################
sub add_google_goods_data {
	# 各値をCSVファイルに書き出す
	# id
	$output_google_goods_csv->combine($global_entry_goods_code) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 商品名
	$output_google_goods_csv->combine($global_entry_goods_name) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 商品説明
	$output_google_goods_csv->combine($global_entry_goods_supp_info) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# google 商品カテゴリ
	my $google_category ="ファッション、アクセサリー > ファッション";
	Encode::from_to( $google_category, 'utf8', 'shiftjis' );
	$output_google_goods_csv->combine($google_category) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 商品リンク
	my $goods_link = "http://glober.jp/g/g".get_5code($global_entry_goods_code);
	$output_google_goods_csv->combine($goods_link) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 商品画像リンク
	$output_google_goods_csv->combine($global_entry_goods_img_info) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 状態
	my $state="新品";
	Encode::from_to( $state, 'utf8', 'shiftjis' );
	$output_google_goods_csv->combine($state) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 在庫状況
	my $stock_situation="";
	if($stock_flag == 1){
		$stock_situation = "在庫あり";
	}else{
		$stock_situation = "予約";
	}
	Encode::from_to( $stock_situation, 'utf8', 'shiftjis' );
	$output_google_goods_csv->combine($stock_situation) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 販売価格
	$output_google_goods_csv->combine($global_entry_goods_price) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# ブランド
	$output_google_goods_csv->combine($global_entry_goods_category) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 性別
	my $sex="男性";
	Encode::from_to( $sex, 'utf8', 'shiftjis' );
	$output_google_goods_csv->combine($sex) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 年齢層
	my $age_groupe="大人";
	Encode::from_to( $age_groupe, 'utf8', 'shiftjis' );
	$output_google_goods_csv->combine($age_groupe) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 色
	$output_google_goods_csv->combine($global_entry_goods_color) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# サイズ
	$output_google_goods_csv->combine($global_entry_goods_size) or die $output_google_goods_csv->error_diag();
	print $output_google_goods_file_disc $output_google_goods_csv->string(), ",";
	# 商品グループid
	$output_google_goods_csv->combine(get_5code($global_entry_goods_code)) or die $output_google_goods_csv->error_diag();
	# 最終行に追加
	print $output_google_goods_file_disc $output_google_goods_csv->string(), "\n";
	return 0;
}

#####################
### ユーティリティ関数　###
#####################
## 指定されたカテゴリ名に対応するカテゴリをXMLファイルから取得する

## ログ出力
sub output_log {
	my $day=&to_YYYYMMDD_string();
	print "[$day]:$_[0]";
	print LOG_FILE "[$day]:$_[0]";
}

## 現在日時取得関数
sub to_YYYYMMDD_string {
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my $result = sprintf("%04d%02d%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
  return $result;
}

sub delete_double_quotation {
	my $str = $_[0] || ""; 
	# ""の存在チェック
	my $substr_begin_point=0;
	if (index($str, "\"", 0) != -1) {
		$substr_begin_point=index($str, "\"", 0);	
	}
	my $substr_end_point=length($str);
	if (rindex($str, "\"") != -1) {
		$substr_end_point = rindex($str, "\"");
	}
	return substr($str, $substr_begin_point, $substr_end_point);
}

sub get_5code {
	return substr(delete_double_quotation($_[0]), 0, 5);
}

sub get_9code {
	return substr(delete_double_quotation($_[0]), 0, 9);
}