



<!DOCTYPE html>
<html lang="en" class="   ">
  <head prefix="og: http://ogp.me/ns# fb: http://ogp.me/ns/fb# object: http://ogp.me/ns/object# article: http://ogp.me/ns/article# profile: http://ogp.me/ns/profile#">
    <meta charset='utf-8'>
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta http-equiv="Content-Language" content="en">
    
    
    <title>logstash/protocol.rb at master · elasticsearch/logstash · GitHub</title>
    <link rel="search" type="application/opensearchdescription+xml" href="/opensearch.xml" title="GitHub">
    <link rel="fluid-icon" href="https://github.com/fluidicon.png" title="GitHub">
    <link rel="apple-touch-icon" sizes="57x57" href="/apple-touch-icon-114.png">
    <link rel="apple-touch-icon" sizes="114x114" href="/apple-touch-icon-114.png">
    <link rel="apple-touch-icon" sizes="72x72" href="/apple-touch-icon-144.png">
    <link rel="apple-touch-icon" sizes="144x144" href="/apple-touch-icon-144.png">
    <meta property="fb:app_id" content="1401488693436528">

      <meta content="@github" name="twitter:site" /><meta content="summary" name="twitter:card" /><meta content="elasticsearch/logstash" name="twitter:title" /><meta content="logstash - logs/event transport, processing, management, search." name="twitter:description" /><meta content="https://avatars2.githubusercontent.com/u/141304?v=2&amp;s=400" name="twitter:image:src" />
<meta content="GitHub" property="og:site_name" /><meta content="object" property="og:type" /><meta content="https://avatars2.githubusercontent.com/u/141304?v=2&amp;s=400" property="og:image" /><meta content="elasticsearch/logstash" property="og:title" /><meta content="https://github.com/elasticsearch/logstash" property="og:url" /><meta content="logstash - logs/event transport, processing, management, search." property="og:description" />

    <link rel="assets" href="https://assets-cdn.github.com/">
    <link rel="conduit-xhr" href="https://ghconduit.com:25035">
    

    <meta name="msapplication-TileImage" content="/windows-tile.png">
    <meta name="msapplication-TileColor" content="#ffffff">
    <meta name="selected-link" value="repo_source" data-pjax-transient>
      <meta name="google-analytics" content="UA-3769691-2">

    <meta content="collector.githubapp.com" name="octolytics-host" /><meta content="collector-cdn.github.com" name="octolytics-script-host" /><meta content="github" name="octolytics-app-id" /><meta content="050952EB:6A3F:3F6EE53:53ECC1C4" name="octolytics-dimension-request_id" />
    

    
    
    <link rel="icon" type="image/x-icon" href="https://assets-cdn.github.com/favicon.ico">


    <meta content="authenticity_token" name="csrf-param" />
<meta content="YKnt2g9bQgnWUXNz/PJhf6YpP8+uPc0YeXwIMb0TvOzcCIsndMShzPgS1QeTgxZaWf/Dnm1rCB2XsiDp/Anw7Q==" name="csrf-token" />

    <link href="https://assets-cdn.github.com/assets/github-9292d024f6948334bdb496c5e7a55d8df86fb80e.css" media="all" rel="stylesheet" type="text/css" />
    <link href="https://assets-cdn.github.com/assets/github2-fe2778113a79ed0985eedf979a34188ceea23f97.css" media="all" rel="stylesheet" type="text/css" />
    


    <meta http-equiv="x-pjax-version" content="f4d07a70fe9c693bc8f53c5731e8976d">

      
  <meta name="description" content="logstash - logs/event transport, processing, management, search.">


  <meta content="141304" name="octolytics-dimension-user_id" /><meta content="elasticsearch" name="octolytics-dimension-user_login" /><meta content="1090311" name="octolytics-dimension-repository_id" /><meta content="elasticsearch/logstash" name="octolytics-dimension-repository_nwo" /><meta content="true" name="octolytics-dimension-repository_public" /><meta content="false" name="octolytics-dimension-repository_is_fork" /><meta content="1090311" name="octolytics-dimension-repository_network_root_id" /><meta content="elasticsearch/logstash" name="octolytics-dimension-repository_network_root_nwo" />
  <link href="https://github.com/elasticsearch/logstash/commits/master.atom" rel="alternate" title="Recent Commits to logstash:master" type="application/atom+xml">

  </head>


  <body class="logged_out  env-production  vis-public page-blob">
    <a href="#start-of-content" tabindex="1" class="accessibility-aid js-skip-to-content">Skip to content</a>
    <div class="wrapper">
      
      
      
      


      
      <div class="header header-logged-out">
  <div class="container clearfix">

    <a class="header-logo-wordmark" href="https://github.com/">
      <span class="mega-octicon octicon-logo-github"></span>
    </a>

    <div class="header-actions">
        <a class="button primary" href="/join">Sign up</a>
      <a class="button signin" href="/login?return_to=%2Felasticsearch%2Flogstash%2Fblob%2Fmaster%2Flib%2Flogstash%2Foutputs%2Felasticsearch%2Fprotocol.rb">Sign in</a>
    </div>

    <div class="command-bar js-command-bar  in-repository">

      <ul class="top-nav">
          <li class="explore"><a href="/explore">Explore</a></li>
          <li class="features"><a href="/features">Features</a></li>
          <li class="enterprise"><a href="https://enterprise.github.com/">Enterprise</a></li>
          <li class="blog"><a href="/blog">Blog</a></li>
      </ul>
        <form accept-charset="UTF-8" action="/search" class="command-bar-form" id="top_search_form" method="get"><div style="margin:0;padding:0;display:inline"><input name="utf8" type="hidden" value="&#x2713;" /></div>

<div class="commandbar">
  <span class="message"></span>
  <input type="text" data-hotkey="s, /" name="q" id="js-command-bar-field" placeholder="Search or type a command" tabindex="1" autocapitalize="off"
    
    
    data-repo="elasticsearch/logstash"
  >
  <div class="display hidden"></div>
</div>

    <input type="hidden" name="nwo" value="elasticsearch/logstash">

    <div class="select-menu js-menu-container js-select-menu search-context-select-menu">
      <span class="minibutton select-menu-button js-menu-target" role="button" aria-haspopup="true">
        <span class="js-select-button">This repository</span>
      </span>

      <div class="select-menu-modal-holder js-menu-content js-navigation-container" aria-hidden="true">
        <div class="select-menu-modal">

          <div class="select-menu-item js-navigation-item js-this-repository-navigation-item selected">
            <span class="select-menu-item-icon octicon octicon-check"></span>
            <input type="radio" class="js-search-this-repository" name="search_target" value="repository" checked="checked">
            <div class="select-menu-item-text js-select-button-text">This repository</div>
          </div> <!-- /.select-menu-item -->

          <div class="select-menu-item js-navigation-item js-all-repositories-navigation-item">
            <span class="select-menu-item-icon octicon octicon-check"></span>
            <input type="radio" name="search_target" value="global">
            <div class="select-menu-item-text js-select-button-text">All repositories</div>
          </div> <!-- /.select-menu-item -->

        </div>
      </div>
    </div>

  <span class="help tooltipped tooltipped-s" aria-label="Show command bar help">
    <span class="octicon octicon-question"></span>
  </span>


  <input type="hidden" name="ref" value="cmdform">

</form>
    </div>

  </div>
</div>



      <div id="start-of-content" class="accessibility-aid"></div>
          <div class="site" itemscope itemtype="http://schema.org/WebPage">
    <div id="js-flash-container">
      
    </div>
    <div class="pagehead repohead instapaper_ignore readability-menu">
      <div class="container">
        
<ul class="pagehead-actions">


  <li>
      <a href="/login?return_to=%2Felasticsearch%2Flogstash"
    class="minibutton with-count star-button tooltipped tooltipped-n"
    aria-label="You must be signed in to star a repository" rel="nofollow">
    <span class="octicon octicon-star"></span>
    Star
  </a>

    <a class="social-count js-social-count" href="/elasticsearch/logstash/stargazers">
      2,839
    </a>

  </li>

    <li>
      <a href="/login?return_to=%2Felasticsearch%2Flogstash"
        class="minibutton with-count js-toggler-target fork-button tooltipped tooltipped-n"
        aria-label="You must be signed in to fork a repository" rel="nofollow">
        <span class="octicon octicon-repo-forked"></span>
        Fork
      </a>
      <a href="/elasticsearch/logstash/network" class="social-count">
        1,101
      </a>
    </li>
</ul>

        <h1 itemscope itemtype="http://data-vocabulary.org/Breadcrumb" class="entry-title public">
          <span class="mega-octicon octicon-repo"></span>
          <span class="author"><a href="/elasticsearch" class="url fn" itemprop="url" rel="author"><span itemprop="title">elasticsearch</span></a></span><!--
       --><span class="path-divider">/</span><!--
       --><strong><a href="/elasticsearch/logstash" class="js-current-repository js-repo-home-link">logstash</a></strong>

          <span class="page-context-loader">
            <img alt="" height="16" src="https://assets-cdn.github.com/images/spinners/octocat-spinner-32.gif" width="16" />
          </span>

        </h1>
      </div><!-- /.container -->
    </div><!-- /.repohead -->

    <div class="container">
      <div class="repository-with-sidebar repo-container new-discussion-timeline  ">
        <div class="repository-sidebar clearfix">
            
<div class="sunken-menu vertical-right repo-nav js-repo-nav js-repository-container-pjax js-octicon-loaders" data-issue-count-url="/elasticsearch/logstash/issues/counts">
  <div class="sunken-menu-contents">
    <ul class="sunken-menu-group">
      <li class="tooltipped tooltipped-w" aria-label="Code">
        <a href="/elasticsearch/logstash" aria-label="Code" class="selected js-selected-navigation-item sunken-menu-item" data-hotkey="g c" data-pjax="true" data-selected-links="repo_source repo_downloads repo_commits repo_releases repo_tags repo_branches /elasticsearch/logstash">
          <span class="octicon octicon-code"></span> <span class="full-word">Code</span>
          <img alt="" class="mini-loader" height="16" src="https://assets-cdn.github.com/images/spinners/octocat-spinner-32.gif" width="16" />
</a>      </li>

        <li class="tooltipped tooltipped-w" aria-label="Issues">
          <a href="/elasticsearch/logstash/issues" aria-label="Issues" class="js-selected-navigation-item sunken-menu-item js-disable-pjax" data-hotkey="g i" data-selected-links="repo_issues repo_labels repo_milestones /elasticsearch/logstash/issues">
            <span class="octicon octicon-issue-opened"></span> <span class="full-word">Issues</span>
            <span class="js-issue-replace-counter"></span>
            <img alt="" class="mini-loader" height="16" src="https://assets-cdn.github.com/images/spinners/octocat-spinner-32.gif" width="16" />
</a>        </li>

      <li class="tooltipped tooltipped-w" aria-label="Pull Requests">
        <a href="/elasticsearch/logstash/pulls" aria-label="Pull Requests" class="js-selected-navigation-item sunken-menu-item js-disable-pjax" data-hotkey="g p" data-selected-links="repo_pulls /elasticsearch/logstash/pulls">
            <span class="octicon octicon-git-pull-request"></span> <span class="full-word">Pull Requests</span>
            <span class="js-pull-replace-counter"></span>
            <img alt="" class="mini-loader" height="16" src="https://assets-cdn.github.com/images/spinners/octocat-spinner-32.gif" width="16" />
</a>      </li>


        <li class="tooltipped tooltipped-w" aria-label="Wiki">
          <a href="/elasticsearch/logstash/wiki" aria-label="Wiki" class="js-selected-navigation-item sunken-menu-item js-disable-pjax" data-hotkey="g w" data-selected-links="repo_wiki /elasticsearch/logstash/wiki">
            <span class="octicon octicon-book"></span> <span class="full-word">Wiki</span>
            <img alt="" class="mini-loader" height="16" src="https://assets-cdn.github.com/images/spinners/octocat-spinner-32.gif" width="16" />
</a>        </li>
    </ul>
    <div class="sunken-menu-separator"></div>
    <ul class="sunken-menu-group">

      <li class="tooltipped tooltipped-w" aria-label="Pulse">
        <a href="/elasticsearch/logstash/pulse/weekly" aria-label="Pulse" class="js-selected-navigation-item sunken-menu-item" data-pjax="true" data-selected-links="pulse /elasticsearch/logstash/pulse/weekly">
          <span class="octicon octicon-pulse"></span> <span class="full-word">Pulse</span>
          <img alt="" class="mini-loader" height="16" src="https://assets-cdn.github.com/images/spinners/octocat-spinner-32.gif" width="16" />
</a>      </li>

      <li class="tooltipped tooltipped-w" aria-label="Graphs">
        <a href="/elasticsearch/logstash/graphs" aria-label="Graphs" class="js-selected-navigation-item sunken-menu-item" data-pjax="true" data-selected-links="repo_graphs repo_contributors /elasticsearch/logstash/graphs">
          <span class="octicon octicon-graph"></span> <span class="full-word">Graphs</span>
          <img alt="" class="mini-loader" height="16" src="https://assets-cdn.github.com/images/spinners/octocat-spinner-32.gif" width="16" />
</a>      </li>
    </ul>


  </div>
</div>

              <div class="only-with-full-nav">
                
  
<div class="clone-url open"
  data-protocol-type="http"
  data-url="/users/set_protocol?protocol_selector=http&amp;protocol_type=clone">
  <h3><strong>HTTPS</strong> clone URL</h3>
  <div class="input-group">
    <input type="text" class="input-mini input-monospace js-url-field"
           value="https://github.com/elasticsearch/logstash.git" readonly="readonly">
    <span class="input-group-button">
      <button aria-label="Copy to clipboard" class="js-zeroclipboard minibutton zeroclipboard-button" data-clipboard-text="https://github.com/elasticsearch/logstash.git" data-copied-hint="Copied!" type="button"><span class="octicon octicon-clippy"></span></button>
    </span>
  </div>
</div>

  
<div class="clone-url "
  data-protocol-type="subversion"
  data-url="/users/set_protocol?protocol_selector=subversion&amp;protocol_type=clone">
  <h3><strong>Subversion</strong> checkout URL</h3>
  <div class="input-group">
    <input type="text" class="input-mini input-monospace js-url-field"
           value="https://github.com/elasticsearch/logstash" readonly="readonly">
    <span class="input-group-button">
      <button aria-label="Copy to clipboard" class="js-zeroclipboard minibutton zeroclipboard-button" data-clipboard-text="https://github.com/elasticsearch/logstash" data-copied-hint="Copied!" type="button"><span class="octicon octicon-clippy"></span></button>
    </span>
  </div>
</div>


<p class="clone-options">You can clone with
      <a href="#" class="js-clone-selector" data-protocol="http">HTTPS</a>
      or <a href="#" class="js-clone-selector" data-protocol="subversion">Subversion</a>.
  <a href="https://help.github.com/articles/which-remote-url-should-i-use" class="help tooltipped tooltipped-n" aria-label="Get help on which URL is right for you.">
    <span class="octicon octicon-question"></span>
  </a>
</p>



                <a href="/elasticsearch/logstash/archive/master.zip"
                   class="minibutton sidebar-button"
                   aria-label="Download elasticsearch/logstash as a zip file"
                   title="Download elasticsearch/logstash as a zip file"
                   rel="nofollow">
                  <span class="octicon octicon-cloud-download"></span>
                  Download ZIP
                </a>
              </div>
        </div><!-- /.repository-sidebar -->

        <div id="js-repo-pjax-container" class="repository-content context-loader-container" data-pjax-container>
          

<a href="/elasticsearch/logstash/blob/6b20d179aaff2da26cebc9a740e73989a112e200/lib/logstash/outputs/elasticsearch/protocol.rb" class="hidden js-permalink-shortcut" data-hotkey="y">Permalink</a>

<!-- blob contrib key: blob_contributors:v21:3acff7b3c96ec22ba1fd65b2e9e5c1dd -->

<div class="file-navigation">
  
<div class="select-menu js-menu-container js-select-menu left">
  <span class="minibutton select-menu-button js-menu-target css-truncate" data-hotkey="w"
    data-master-branch="master"
    data-ref="master"
    title="master"
    role="button" aria-label="Switch branches or tags" tabindex="0" aria-haspopup="true">
    <span class="octicon octicon-git-branch"></span>
    <i>branch:</i>
    <span class="js-select-button css-truncate-target">master</span>
  </span>

  <div class="select-menu-modal-holder js-menu-content js-navigation-container" data-pjax aria-hidden="true">

    <div class="select-menu-modal">
      <div class="select-menu-header">
        <span class="select-menu-title">Switch branches/tags</span>
        <span class="octicon octicon-x js-menu-close" role="button" aria-label="Close"></span>
      </div> <!-- /.select-menu-header -->

      <div class="select-menu-filters">
        <div class="select-menu-text-filter">
          <input type="text" aria-label="Filter branches/tags" id="context-commitish-filter-field" class="js-filterable-field js-navigation-enable" placeholder="Filter branches/tags">
        </div>
        <div class="select-menu-tabs">
          <ul>
            <li class="select-menu-tab">
              <a href="#" data-tab-filter="branches" class="js-select-menu-tab">Branches</a>
            </li>
            <li class="select-menu-tab">
              <a href="#" data-tab-filter="tags" class="js-select-menu-tab">Tags</a>
            </li>
          </ul>
        </div><!-- /.select-menu-tabs -->
      </div><!-- /.select-menu-filters -->

      <div class="select-menu-list select-menu-tab-bucket js-select-menu-tab-bucket" data-tab-filter="branches">

        <div data-filterable-for="context-commitish-filter-field" data-filterable-type="substring">


            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/1.3.x/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="1.3.x"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="1.3.x">1.3.x</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/1.4/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="1.4"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="1.4">1.4</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/1.x/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="1.x"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="1.x">1.x</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/LOGSTASH-1509/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="LOGSTASH-1509"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="LOGSTASH-1509">LOGSTASH-1509</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/bug/fix-es-embedded-startup-delay/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="bug/fix-es-embedded-startup-delay"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="bug/fix-es-embedded-startup-delay">bug/fix-es-embedded-startup-delay</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/es-config/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="es-config"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="es-config">es-config</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/feature/faster_json/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="feature/faster_json"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="feature/faster_json">feature/faster_json</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/feature/filter-flushing-execution/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="feature/filter-flushing-execution"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="feature/filter-flushing-execution">feature/filter-flushing-execution</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/fix/drip/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="fix/drip"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="fix/drip">fix/drip</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/fix/twitter_keys/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="fix/twitter_keys"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="fix/twitter_keys">fix/twitter_keys</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item selected">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/master/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="master"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="master">master</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/s3-input-default-region-bug/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="s3-input-default-region-bug"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="s3-input-default-region-bug">s3-input-default-region-bug</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/blob/some-compressor-patch-i-forgot/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="some-compressor-patch-i-forgot"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="some-compressor-patch-i-forgot">some-compressor-patch-i-forgot</a>
            </div> <!-- /.select-menu-item -->
        </div>

          <div class="select-menu-no-results">Nothing to show</div>
      </div> <!-- /.select-menu-list -->

      <div class="select-menu-list select-menu-tab-bucket js-select-menu-tab-bucket" data-tab-filter="tags">
        <div data-filterable-for="context-commitish-filter-field" data-filterable-type="substring">


            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.4.2/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.4.2"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.4.2">v1.4.2</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.4.1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.4.1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.4.1">v1.4.1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.4.0.rc1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.4.0.rc1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.4.0.rc1">v1.4.0.rc1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.4.0.beta2/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.4.0.beta2"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.4.0.beta2">v1.4.0.beta2</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.4.0.beta1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.4.0.beta1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.4.0.beta1">v1.4.0.beta1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.4.0/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.4.0"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.4.0">v1.4.0</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.3.3/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.3.3"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.3.3">v1.3.3</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.3.2/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.3.2"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.3.2">v1.3.2</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.3.1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.3.1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.3.1">v1.3.1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.3.0/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.3.0"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.3.0">v1.3.0</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.2.2/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.2.2"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.2.2">v1.2.2</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.2.1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.2.1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.2.1">v1.2.1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.2.0.beta2/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.2.0.beta2"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.2.0.beta2">v1.2.0.beta2</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.2.0.beta1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.2.0.beta1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.2.0.beta1">v1.2.0.beta1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.2.0/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.2.0"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.2.0">v1.2.0</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.13/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.13"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.13">v1.1.13</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.12/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.12"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.12">v1.1.12</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.11/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.11"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.11">v1.1.11</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.10/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.10"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.10">v1.1.10</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.9/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.9"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.9">v1.1.9</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.8/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.8"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.8">v1.1.8</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.7/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.7"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.7">v1.1.7</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.6/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.6"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.6">v1.1.6</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.5/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.5"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.5">v1.1.5</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.4/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.4"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.4">v1.1.4</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.3/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.3"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.3">v1.1.3</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.2/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.2"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.2">v1.1.2</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.1-rc1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.1-rc1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.1-rc1">v1.1.1-rc1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.1">v1.1.1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.0beta9/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.0beta9"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.0beta9">v1.1.0beta9</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.0beta8/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.0beta8"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.0beta8">v1.1.0beta8</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.0beta7/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.0beta7"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.0beta7">v1.1.0beta7</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.0.1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.0.1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.0.1">v1.1.0.1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.1.0/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.1.0"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.1.0">v1.1.0</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.17/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.17"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.17">v1.0.17</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.16/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.16"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.16">v1.0.16</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.15/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.15"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.15">v1.0.15</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.14/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.14"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.14">v1.0.14</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.12/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.12"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.12">v1.0.12</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.11/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.11"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.11">v1.0.11</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.10/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.10"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.10">v1.0.10</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.9/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.9"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.9">v1.0.9</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.7/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.7"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.7">v1.0.7</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.6/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.6"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.6">v1.0.6</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.5/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.5"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.5">v1.0.5</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.4/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.4"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.4">v1.0.4</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.1/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.1"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.1">v1.0.1</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v1.0.0/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v1.0.0"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v1.0.0">v1.0.0</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/v/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="v"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="v">v</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/now/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="now"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="now">now</a>
            </div> <!-- /.select-menu-item -->
            <div class="select-menu-item js-navigation-item ">
              <span class="select-menu-item-icon octicon octicon-check"></span>
              <a href="/elasticsearch/logstash/tree/1.0.4/lib/logstash/outputs/elasticsearch/protocol.rb"
                 data-name="1.0.4"
                 data-skip-pjax="true"
                 rel="nofollow"
                 class="js-navigation-open select-menu-item-text css-truncate-target"
                 title="1.0.4">1.0.4</a>
            </div> <!-- /.select-menu-item -->
        </div>

        <div class="select-menu-no-results">Nothing to show</div>
      </div> <!-- /.select-menu-list -->

    </div> <!-- /.select-menu-modal -->
  </div> <!-- /.select-menu-modal-holder -->
</div> <!-- /.select-menu -->

  <div class="button-group right">
    <a href="/elasticsearch/logstash/find/master"
          class="js-show-file-finder minibutton empty-icon tooltipped tooltipped-s"
          data-pjax
          data-hotkey="t"
          aria-label="Quickly jump between files">
      <span class="octicon octicon-list-unordered"></span>
    </a>
    <button class="js-zeroclipboard minibutton zeroclipboard-button"
          data-clipboard-text="lib/logstash/outputs/elasticsearch/protocol.rb"
          aria-label="Copy to clipboard"
          data-copied-hint="Copied!">
      <span class="octicon octicon-clippy"></span>
    </button>
  </div>

  <div class="breadcrumb">
    <span class='repo-root js-repo-root'><span itemscope="" itemtype="http://data-vocabulary.org/Breadcrumb"><a href="/elasticsearch/logstash" class="" data-branch="master" data-direction="back" data-pjax="true" itemscope="url"><span itemprop="title">logstash</span></a></span></span><span class="separator"> / </span><span itemscope="" itemtype="http://data-vocabulary.org/Breadcrumb"><a href="/elasticsearch/logstash/tree/master/lib" class="" data-branch="master" data-direction="back" data-pjax="true" itemscope="url"><span itemprop="title">lib</span></a></span><span class="separator"> / </span><span itemscope="" itemtype="http://data-vocabulary.org/Breadcrumb"><a href="/elasticsearch/logstash/tree/master/lib/logstash" class="" data-branch="master" data-direction="back" data-pjax="true" itemscope="url"><span itemprop="title">logstash</span></a></span><span class="separator"> / </span><span itemscope="" itemtype="http://data-vocabulary.org/Breadcrumb"><a href="/elasticsearch/logstash/tree/master/lib/logstash/outputs" class="" data-branch="master" data-direction="back" data-pjax="true" itemscope="url"><span itemprop="title">outputs</span></a></span><span class="separator"> / </span><span itemscope="" itemtype="http://data-vocabulary.org/Breadcrumb"><a href="/elasticsearch/logstash/tree/master/lib/logstash/outputs/elasticsearch" class="" data-branch="master" data-direction="back" data-pjax="true" itemscope="url"><span itemprop="title">elasticsearch</span></a></span><span class="separator"> / </span><strong class="final-path">protocol.rb</strong>
  </div>
</div>


  <div class="commit file-history-tease">
      <img alt="Colin Surprenant" class="main-avatar" data-user="2010" height="24" src="https://avatars3.githubusercontent.com/u/2010?v=2&amp;s=48" width="24" />
      <span class="author"><a href="/colinsurprenant" rel="contributor">colinsurprenant</a></span>
      <time datetime="2014-06-12T17:53:30-04:00" is="relative-time">June 12, 2014</time>
      <div class="commit-title">
          <a href="/elasticsearch/logstash/commit/e03b67dc7da0c3d654caef9ca1a144d1ab99e580" class="message" data-pjax="true" title="replace json parsers with JrJackson and Oj
refactored timestamps with new Timestamp class
closes #1434">replace json parsers with JrJackson and Oj</a>
      </div>

    <div class="participation">
      <p class="quickstat"><a href="#blob_contributors_box" rel="facebox"><strong>2</strong>  contributors</a></p>
      
    <a class="avatar tooltipped tooltipped-s" aria-label="jordansissel" href="/elasticsearch/logstash/commits/master/lib/logstash/outputs/elasticsearch/protocol.rb?author=jordansissel"><img alt="Jordan Sissel" data-user="131818" height="20" src="https://avatars1.githubusercontent.com/u/131818?v=2&amp;s=40" width="20" /></a>
    <a class="avatar tooltipped tooltipped-s" aria-label="colinsurprenant" href="/elasticsearch/logstash/commits/master/lib/logstash/outputs/elasticsearch/protocol.rb?author=colinsurprenant"><img alt="Colin Surprenant" data-user="2010" height="20" src="https://avatars1.githubusercontent.com/u/2010?v=2&amp;s=40" width="20" /></a>


    </div>
    <div id="blob_contributors_box" style="display:none">
      <h2 class="facebox-header">Users who have contributed to this file</h2>
      <ul class="facebox-user-list">
          <li class="facebox-user-list-item">
            <img alt="Jordan Sissel" data-user="131818" height="24" src="https://avatars3.githubusercontent.com/u/131818?v=2&amp;s=48" width="24" />
            <a href="/jordansissel">jordansissel</a>
          </li>
          <li class="facebox-user-list-item">
            <img alt="Colin Surprenant" data-user="2010" height="24" src="https://avatars3.githubusercontent.com/u/2010?v=2&amp;s=48" width="24" />
            <a href="/colinsurprenant">colinsurprenant</a>
          </li>
      </ul>
    </div>
  </div>

<div class="file-box">
  <div class="file">
    <div class="meta clearfix">
      <div class="info file-name">
          <span>272 lines (228 sloc)</span>
          <span class="meta-divider"></span>
        <span>8.313 kb</span>
      </div>
      <div class="actions">
        <div class="button-group">
          <a href="/elasticsearch/logstash/raw/master/lib/logstash/outputs/elasticsearch/protocol.rb" class="minibutton " id="raw-url">Raw</a>
            <a href="/elasticsearch/logstash/blame/master/lib/logstash/outputs/elasticsearch/protocol.rb" class="minibutton js-update-url-with-hash">Blame</a>
          <a href="/elasticsearch/logstash/commits/master/lib/logstash/outputs/elasticsearch/protocol.rb" class="minibutton " rel="nofollow">History</a>
        </div><!-- /.button-group -->


            <a class="octicon-button disabled tooltipped tooltipped-w" href="#"
               aria-label="You must be signed in to make or propose changes"><span class="octicon octicon-pencil"></span></a>

          <a class="octicon-button danger disabled tooltipped tooltipped-w" href="#"
             aria-label="You must be signed in to make or propose changes">
          <span class="octicon octicon-trashcan"></span>
        </a>
      </div><!-- /.actions -->
    </div>
      
  <div class="blob-wrapper data type-ruby">
      
<table class="highlight tab-size-8 js-file-line-container">
      <tr>
        <td id="L1" class="blob-line-num js-line-number" data-line-number="1"></td>
        <td id="LC1" class="blob-line-code js-file-line"><span class="nb">require</span> <span class="s2">&quot;logstash/outputs/elasticsearch&quot;</span></td>
      </tr>
      <tr>
        <td id="L2" class="blob-line-num js-line-number" data-line-number="2"></td>
        <td id="LC2" class="blob-line-code js-file-line"><span class="nb">require</span> <span class="s2">&quot;cabin&quot;</span></td>
      </tr>
      <tr>
        <td id="L3" class="blob-line-num js-line-number" data-line-number="3"></td>
        <td id="LC3" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L4" class="blob-line-num js-line-number" data-line-number="4"></td>
        <td id="LC4" class="blob-line-code js-file-line"><span class="k">module</span> <span class="nn">LogStash::Outputs::Elasticsearch</span></td>
      </tr>
      <tr>
        <td id="L5" class="blob-line-num js-line-number" data-line-number="5"></td>
        <td id="LC5" class="blob-line-code js-file-line">  <span class="k">module</span> <span class="nn">Protocols</span></td>
      </tr>
      <tr>
        <td id="L6" class="blob-line-num js-line-number" data-line-number="6"></td>
        <td id="LC6" class="blob-line-code js-file-line">    <span class="k">class</span> <span class="nc">Base</span></td>
      </tr>
      <tr>
        <td id="L7" class="blob-line-num js-line-number" data-line-number="7"></td>
        <td id="LC7" class="blob-line-code js-file-line">      <span class="kp">private</span></td>
      </tr>
      <tr>
        <td id="L8" class="blob-line-num js-line-number" data-line-number="8"></td>
        <td id="LC8" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">initialize</span><span class="p">(</span><span class="n">options</span><span class="o">=</span><span class="p">{})</span></td>
      </tr>
      <tr>
        <td id="L9" class="blob-line-num js-line-number" data-line-number="9"></td>
        <td id="LC9" class="blob-line-code js-file-line">        <span class="c1"># host(s), port, cluster</span></td>
      </tr>
      <tr>
        <td id="L10" class="blob-line-num js-line-number" data-line-number="10"></td>
        <td id="LC10" class="blob-line-code js-file-line">        <span class="vi">@logger</span> <span class="o">=</span> <span class="no">Cabin</span><span class="o">::</span><span class="no">Channel</span><span class="o">.</span><span class="n">get</span></td>
      </tr>
      <tr>
        <td id="L11" class="blob-line-num js-line-number" data-line-number="11"></td>
        <td id="LC11" class="blob-line-code js-file-line">      <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L12" class="blob-line-num js-line-number" data-line-number="12"></td>
        <td id="LC12" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L13" class="blob-line-num js-line-number" data-line-number="13"></td>
        <td id="LC13" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">client</span></td>
      </tr>
      <tr>
        <td id="L14" class="blob-line-num js-line-number" data-line-number="14"></td>
        <td id="LC14" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="vi">@client</span> <span class="k">if</span> <span class="vi">@client</span></td>
      </tr>
      <tr>
        <td id="L15" class="blob-line-num js-line-number" data-line-number="15"></td>
        <td id="LC15" class="blob-line-code js-file-line">        <span class="vi">@client</span> <span class="o">=</span> <span class="n">build_client</span><span class="p">(</span><span class="vi">@options</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L16" class="blob-line-num js-line-number" data-line-number="16"></td>
        <td id="LC16" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="vi">@client</span></td>
      </tr>
      <tr>
        <td id="L17" class="blob-line-num js-line-number" data-line-number="17"></td>
        <td id="LC17" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def client</span></td>
      </tr>
      <tr>
        <td id="L18" class="blob-line-num js-line-number" data-line-number="18"></td>
        <td id="LC18" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L19" class="blob-line-num js-line-number" data-line-number="19"></td>
        <td id="LC19" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L20" class="blob-line-num js-line-number" data-line-number="20"></td>
        <td id="LC20" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">template_install</span><span class="p">(</span><span class="nb">name</span><span class="p">,</span> <span class="n">template</span><span class="p">,</span> <span class="n">force</span><span class="o">=</span><span class="kp">false</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L21" class="blob-line-num js-line-number" data-line-number="21"></td>
        <td id="LC21" class="blob-line-code js-file-line">        <span class="k">if</span> <span class="n">template_exists?</span><span class="p">(</span><span class="nb">name</span><span class="p">)</span> <span class="o">&amp;&amp;</span> <span class="o">!</span><span class="n">force</span></td>
      </tr>
      <tr>
        <td id="L22" class="blob-line-num js-line-number" data-line-number="22"></td>
        <td id="LC22" class="blob-line-code js-file-line">          <span class="vi">@logger</span><span class="o">.</span><span class="n">debug</span><span class="p">(</span><span class="s2">&quot;Found existing Elasticsearch template. Skipping template management&quot;</span><span class="p">,</span> <span class="ss">:name</span> <span class="o">=&gt;</span> <span class="nb">name</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L23" class="blob-line-num js-line-number" data-line-number="23"></td>
        <td id="LC23" class="blob-line-code js-file-line">          <span class="k">return</span></td>
      </tr>
      <tr>
        <td id="L24" class="blob-line-num js-line-number" data-line-number="24"></td>
        <td id="LC24" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L25" class="blob-line-num js-line-number" data-line-number="25"></td>
        <td id="LC25" class="blob-line-code js-file-line">        <span class="n">template_put</span><span class="p">(</span><span class="nb">name</span><span class="p">,</span> <span class="n">template</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L26" class="blob-line-num js-line-number" data-line-number="26"></td>
        <td id="LC26" class="blob-line-code js-file-line">      <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L27" class="blob-line-num js-line-number" data-line-number="27"></td>
        <td id="LC27" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L28" class="blob-line-num js-line-number" data-line-number="28"></td>
        <td id="LC28" class="blob-line-code js-file-line">      <span class="c1"># Do a bulk request with the given actions.</span></td>
      </tr>
      <tr>
        <td id="L29" class="blob-line-num js-line-number" data-line-number="29"></td>
        <td id="LC29" class="blob-line-code js-file-line">      <span class="c1">#</span></td>
      </tr>
      <tr>
        <td id="L30" class="blob-line-num js-line-number" data-line-number="30"></td>
        <td id="LC30" class="blob-line-code js-file-line">      <span class="c1"># &#39;actions&#39; is expected to be an array of bulk requests as string json</span></td>
      </tr>
      <tr>
        <td id="L31" class="blob-line-num js-line-number" data-line-number="31"></td>
        <td id="LC31" class="blob-line-code js-file-line">      <span class="c1"># values.</span></td>
      </tr>
      <tr>
        <td id="L32" class="blob-line-num js-line-number" data-line-number="32"></td>
        <td id="LC32" class="blob-line-code js-file-line">      <span class="c1">#</span></td>
      </tr>
      <tr>
        <td id="L33" class="blob-line-num js-line-number" data-line-number="33"></td>
        <td id="LC33" class="blob-line-code js-file-line">      <span class="c1"># Each &#39;action&#39; becomes a single line in the bulk api call. For more</span></td>
      </tr>
      <tr>
        <td id="L34" class="blob-line-num js-line-number" data-line-number="34"></td>
        <td id="LC34" class="blob-line-code js-file-line">      <span class="c1"># details on the format of each.</span></td>
      </tr>
      <tr>
        <td id="L35" class="blob-line-num js-line-number" data-line-number="35"></td>
        <td id="LC35" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">bulk</span><span class="p">(</span><span class="n">actions</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L36" class="blob-line-num js-line-number" data-line-number="36"></td>
        <td id="LC36" class="blob-line-code js-file-line">        <span class="k">raise</span> <span class="no">NotImplemented</span><span class="p">,</span> <span class="s2">&quot;You must implement this yourself&quot;</span></td>
      </tr>
      <tr>
        <td id="L37" class="blob-line-num js-line-number" data-line-number="37"></td>
        <td id="LC37" class="blob-line-code js-file-line">        <span class="c1"># bulk([</span></td>
      </tr>
      <tr>
        <td id="L38" class="blob-line-num js-line-number" data-line-number="38"></td>
        <td id="LC38" class="blob-line-code js-file-line">        <span class="c1"># &#39;{ &quot;index&quot; : { &quot;_index&quot; : &quot;test&quot;, &quot;_type&quot; : &quot;type1&quot;, &quot;_id&quot; : &quot;1&quot; } }&#39;,</span></td>
      </tr>
      <tr>
        <td id="L39" class="blob-line-num js-line-number" data-line-number="39"></td>
        <td id="LC39" class="blob-line-code js-file-line">        <span class="c1"># &#39;{ &quot;field1&quot; : &quot;value1&quot; }&#39;</span></td>
      </tr>
      <tr>
        <td id="L40" class="blob-line-num js-line-number" data-line-number="40"></td>
        <td id="LC40" class="blob-line-code js-file-line">        <span class="c1">#])</span></td>
      </tr>
      <tr>
        <td id="L41" class="blob-line-num js-line-number" data-line-number="41"></td>
        <td id="LC41" class="blob-line-code js-file-line">      <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L42" class="blob-line-num js-line-number" data-line-number="42"></td>
        <td id="LC42" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L43" class="blob-line-num js-line-number" data-line-number="43"></td>
        <td id="LC43" class="blob-line-code js-file-line">      <span class="kp">public</span><span class="p">(</span><span class="ss">:initialize</span><span class="p">,</span> <span class="ss">:template_install</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L44" class="blob-line-num js-line-number" data-line-number="44"></td>
        <td id="LC44" class="blob-line-code js-file-line">    <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L45" class="blob-line-num js-line-number" data-line-number="45"></td>
        <td id="LC45" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L46" class="blob-line-num js-line-number" data-line-number="46"></td>
        <td id="LC46" class="blob-line-code js-file-line">    <span class="k">class</span> <span class="nc">HTTPClient</span> <span class="o">&lt;</span> <span class="no">Base</span></td>
      </tr>
      <tr>
        <td id="L47" class="blob-line-num js-line-number" data-line-number="47"></td>
        <td id="LC47" class="blob-line-code js-file-line">      <span class="kp">private</span></td>
      </tr>
      <tr>
        <td id="L48" class="blob-line-num js-line-number" data-line-number="48"></td>
        <td id="LC48" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L49" class="blob-line-num js-line-number" data-line-number="49"></td>
        <td id="LC49" class="blob-line-code js-file-line">      <span class="no">DEFAULT_OPTIONS</span> <span class="o">=</span> <span class="p">{</span></td>
      </tr>
      <tr>
        <td id="L50" class="blob-line-num js-line-number" data-line-number="50"></td>
        <td id="LC50" class="blob-line-code js-file-line">        <span class="ss">:port</span> <span class="o">=&gt;</span> <span class="mi">9200</span></td>
      </tr>
      <tr>
        <td id="L51" class="blob-line-num js-line-number" data-line-number="51"></td>
        <td id="LC51" class="blob-line-code js-file-line">      <span class="p">}</span></td>
      </tr>
      <tr>
        <td id="L52" class="blob-line-num js-line-number" data-line-number="52"></td>
        <td id="LC52" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L53" class="blob-line-num js-line-number" data-line-number="53"></td>
        <td id="LC53" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">initialize</span><span class="p">(</span><span class="n">options</span><span class="o">=</span><span class="p">{})</span></td>
      </tr>
      <tr>
        <td id="L54" class="blob-line-num js-line-number" data-line-number="54"></td>
        <td id="LC54" class="blob-line-code js-file-line">        <span class="nb">require</span> <span class="s2">&quot;ftw&quot;</span></td>
      </tr>
      <tr>
        <td id="L55" class="blob-line-num js-line-number" data-line-number="55"></td>
        <td id="LC55" class="blob-line-code js-file-line">        <span class="k">super</span></td>
      </tr>
      <tr>
        <td id="L56" class="blob-line-num js-line-number" data-line-number="56"></td>
        <td id="LC56" class="blob-line-code js-file-line">        <span class="nb">require</span> <span class="s2">&quot;elasticsearch&quot;</span> <span class="c1"># gem &#39;elasticsearch-ruby&#39;</span></td>
      </tr>
      <tr>
        <td id="L57" class="blob-line-num js-line-number" data-line-number="57"></td>
        <td id="LC57" class="blob-line-code js-file-line">        <span class="vi">@options</span> <span class="o">=</span> <span class="no">DEFAULT_OPTIONS</span><span class="o">.</span><span class="n">merge</span><span class="p">(</span><span class="n">options</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L58" class="blob-line-num js-line-number" data-line-number="58"></td>
        <td id="LC58" class="blob-line-code js-file-line">        <span class="vi">@client</span> <span class="o">=</span> <span class="n">client</span></td>
      </tr>
      <tr>
        <td id="L59" class="blob-line-num js-line-number" data-line-number="59"></td>
        <td id="LC59" class="blob-line-code js-file-line">      <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L60" class="blob-line-num js-line-number" data-line-number="60"></td>
        <td id="LC60" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L61" class="blob-line-num js-line-number" data-line-number="61"></td>
        <td id="LC61" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">build_client</span><span class="p">(</span><span class="n">options</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L62" class="blob-line-num js-line-number" data-line-number="62"></td>
        <td id="LC62" class="blob-line-code js-file-line">        <span class="n">client</span> <span class="o">=</span> <span class="no">Elasticsearch</span><span class="o">::</span><span class="no">Client</span><span class="o">.</span><span class="n">new</span><span class="p">(</span></td>
      </tr>
      <tr>
        <td id="L63" class="blob-line-num js-line-number" data-line-number="63"></td>
        <td id="LC63" class="blob-line-code js-file-line">          <span class="ss">:host</span> <span class="o">=&gt;</span> <span class="o">[</span><span class="n">options</span><span class="o">[</span><span class="ss">:host</span><span class="o">]</span><span class="p">,</span> <span class="n">options</span><span class="o">[</span><span class="ss">:port</span><span class="o">]].</span><span class="n">join</span><span class="p">(</span><span class="s2">&quot;:&quot;</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L64" class="blob-line-num js-line-number" data-line-number="64"></td>
        <td id="LC64" class="blob-line-code js-file-line">        <span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L65" class="blob-line-num js-line-number" data-line-number="65"></td>
        <td id="LC65" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L66" class="blob-line-num js-line-number" data-line-number="66"></td>
        <td id="LC66" class="blob-line-code js-file-line">        <span class="c1"># Use FTW to do indexing requests, for now, until we</span></td>
      </tr>
      <tr>
        <td id="L67" class="blob-line-num js-line-number" data-line-number="67"></td>
        <td id="LC67" class="blob-line-code js-file-line">        <span class="c1"># can identify and resolve performance problems of elasticsearch-ruby</span></td>
      </tr>
      <tr>
        <td id="L68" class="blob-line-num js-line-number" data-line-number="68"></td>
        <td id="LC68" class="blob-line-code js-file-line">        <span class="vi">@bulk_url</span> <span class="o">=</span> <span class="s2">&quot;http://</span><span class="si">#{</span><span class="n">options</span><span class="o">[</span><span class="ss">:host</span><span class="o">]</span><span class="si">}</span><span class="s2">:</span><span class="si">#{</span><span class="n">options</span><span class="o">[</span><span class="ss">:port</span><span class="o">]</span><span class="si">}</span><span class="s2">/_bulk&quot;</span></td>
      </tr>
      <tr>
        <td id="L69" class="blob-line-num js-line-number" data-line-number="69"></td>
        <td id="LC69" class="blob-line-code js-file-line">        <span class="vi">@agent</span> <span class="o">=</span> <span class="no">FTW</span><span class="o">::</span><span class="no">Agent</span><span class="o">.</span><span class="n">new</span></td>
      </tr>
      <tr>
        <td id="L70" class="blob-line-num js-line-number" data-line-number="70"></td>
        <td id="LC70" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L71" class="blob-line-num js-line-number" data-line-number="71"></td>
        <td id="LC71" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="n">client</span></td>
      </tr>
      <tr>
        <td id="L72" class="blob-line-num js-line-number" data-line-number="72"></td>
        <td id="LC72" class="blob-line-code js-file-line">      <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L73" class="blob-line-num js-line-number" data-line-number="73"></td>
        <td id="LC73" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L74" class="blob-line-num js-line-number" data-line-number="74"></td>
        <td id="LC74" class="blob-line-code js-file-line">      <span class="k">if</span> <span class="no">ENV</span><span class="o">[</span><span class="s2">&quot;BULK&quot;</span><span class="o">]</span> <span class="o">==</span> <span class="s2">&quot;esruby&quot;</span></td>
      </tr>
      <tr>
        <td id="L75" class="blob-line-num js-line-number" data-line-number="75"></td>
        <td id="LC75" class="blob-line-code js-file-line">        <span class="k">def</span> <span class="nf">bulk</span><span class="p">(</span><span class="n">actions</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L76" class="blob-line-num js-line-number" data-line-number="76"></td>
        <td id="LC76" class="blob-line-code js-file-line">          <span class="n">bulk_esruby</span><span class="p">(</span><span class="n">actions</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L77" class="blob-line-num js-line-number" data-line-number="77"></td>
        <td id="LC77" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L78" class="blob-line-num js-line-number" data-line-number="78"></td>
        <td id="LC78" class="blob-line-code js-file-line">      <span class="k">else</span></td>
      </tr>
      <tr>
        <td id="L79" class="blob-line-num js-line-number" data-line-number="79"></td>
        <td id="LC79" class="blob-line-code js-file-line">        <span class="k">def</span> <span class="nf">bulk</span><span class="p">(</span><span class="n">actions</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L80" class="blob-line-num js-line-number" data-line-number="80"></td>
        <td id="LC80" class="blob-line-code js-file-line">          <span class="n">bulk_ftw</span><span class="p">(</span><span class="n">actions</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L81" class="blob-line-num js-line-number" data-line-number="81"></td>
        <td id="LC81" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L82" class="blob-line-num js-line-number" data-line-number="82"></td>
        <td id="LC82" class="blob-line-code js-file-line">      <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L83" class="blob-line-num js-line-number" data-line-number="83"></td>
        <td id="LC83" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L84" class="blob-line-num js-line-number" data-line-number="84"></td>
        <td id="LC84" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">bulk_esruby</span><span class="p">(</span><span class="n">actions</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L85" class="blob-line-num js-line-number" data-line-number="85"></td>
        <td id="LC85" class="blob-line-code js-file-line">        <span class="vi">@client</span><span class="o">.</span><span class="n">bulk</span><span class="p">(</span><span class="ss">:body</span> <span class="o">=&gt;</span> <span class="n">actions</span><span class="o">.</span><span class="n">collect</span> <span class="k">do</span> <span class="o">|</span><span class="n">action</span><span class="p">,</span> <span class="n">args</span><span class="p">,</span> <span class="n">source</span><span class="o">|</span></td>
      </tr>
      <tr>
        <td id="L86" class="blob-line-num js-line-number" data-line-number="86"></td>
        <td id="LC86" class="blob-line-code js-file-line">          <span class="k">if</span> <span class="n">source</span></td>
      </tr>
      <tr>
        <td id="L87" class="blob-line-num js-line-number" data-line-number="87"></td>
        <td id="LC87" class="blob-line-code js-file-line">            <span class="k">next</span> <span class="o">[</span> <span class="p">{</span> <span class="n">action</span> <span class="o">=&gt;</span> <span class="n">args</span> <span class="p">},</span> <span class="n">source</span> <span class="o">]</span></td>
      </tr>
      <tr>
        <td id="L88" class="blob-line-num js-line-number" data-line-number="88"></td>
        <td id="LC88" class="blob-line-code js-file-line">          <span class="k">else</span></td>
      </tr>
      <tr>
        <td id="L89" class="blob-line-num js-line-number" data-line-number="89"></td>
        <td id="LC89" class="blob-line-code js-file-line">            <span class="k">next</span> <span class="p">{</span> <span class="n">action</span> <span class="o">=&gt;</span> <span class="n">args</span> <span class="p">}</span></td>
      </tr>
      <tr>
        <td id="L90" class="blob-line-num js-line-number" data-line-number="90"></td>
        <td id="LC90" class="blob-line-code js-file-line">          <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L91" class="blob-line-num js-line-number" data-line-number="91"></td>
        <td id="LC91" class="blob-line-code js-file-line">        <span class="k">end</span><span class="o">.</span><span class="n">flatten</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L92" class="blob-line-num js-line-number" data-line-number="92"></td>
        <td id="LC92" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def bulk_esruby</span></td>
      </tr>
      <tr>
        <td id="L93" class="blob-line-num js-line-number" data-line-number="93"></td>
        <td id="LC93" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L94" class="blob-line-num js-line-number" data-line-number="94"></td>
        <td id="LC94" class="blob-line-code js-file-line">      <span class="c1"># Avoid creating a new string for newline every time</span></td>
      </tr>
      <tr>
        <td id="L95" class="blob-line-num js-line-number" data-line-number="95"></td>
        <td id="LC95" class="blob-line-code js-file-line">      <span class="no">NEWLINE</span> <span class="o">=</span> <span class="s2">&quot;</span><span class="se">\n</span><span class="s2">&quot;</span><span class="o">.</span><span class="n">freeze</span></td>
      </tr>
      <tr>
        <td id="L96" class="blob-line-num js-line-number" data-line-number="96"></td>
        <td id="LC96" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">bulk_ftw</span><span class="p">(</span><span class="n">actions</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L97" class="blob-line-num js-line-number" data-line-number="97"></td>
        <td id="LC97" class="blob-line-code js-file-line">        <span class="n">body</span> <span class="o">=</span> <span class="n">actions</span><span class="o">.</span><span class="n">collect</span> <span class="k">do</span> <span class="o">|</span><span class="n">action</span><span class="p">,</span> <span class="n">args</span><span class="p">,</span> <span class="n">source</span><span class="o">|</span></td>
      </tr>
      <tr>
        <td id="L98" class="blob-line-num js-line-number" data-line-number="98"></td>
        <td id="LC98" class="blob-line-code js-file-line">          <span class="n">header</span> <span class="o">=</span> <span class="p">{</span> <span class="n">action</span> <span class="o">=&gt;</span> <span class="n">args</span> <span class="p">}</span></td>
      </tr>
      <tr>
        <td id="L99" class="blob-line-num js-line-number" data-line-number="99"></td>
        <td id="LC99" class="blob-line-code js-file-line">          <span class="k">if</span> <span class="n">source</span></td>
      </tr>
      <tr>
        <td id="L100" class="blob-line-num js-line-number" data-line-number="100"></td>
        <td id="LC100" class="blob-line-code js-file-line">            <span class="k">next</span> <span class="o">[</span> <span class="no">LogStash</span><span class="o">::</span><span class="no">Json</span><span class="o">.</span><span class="n">dump</span><span class="p">(</span><span class="n">header</span><span class="p">),</span> <span class="no">NEWLINE</span><span class="p">,</span> <span class="no">LogStash</span><span class="o">::</span><span class="no">Json</span><span class="o">.</span><span class="n">dump</span><span class="p">(</span><span class="n">source</span><span class="p">),</span> <span class="no">NEWLINE</span> <span class="o">]</span></td>
      </tr>
      <tr>
        <td id="L101" class="blob-line-num js-line-number" data-line-number="101"></td>
        <td id="LC101" class="blob-line-code js-file-line">          <span class="k">else</span></td>
      </tr>
      <tr>
        <td id="L102" class="blob-line-num js-line-number" data-line-number="102"></td>
        <td id="LC102" class="blob-line-code js-file-line">            <span class="k">next</span> <span class="o">[</span> <span class="no">LogStash</span><span class="o">::</span><span class="no">Json</span><span class="o">.</span><span class="n">dump</span><span class="p">(</span><span class="n">header</span><span class="p">),</span> <span class="no">NEWLINE</span> <span class="o">]</span></td>
      </tr>
      <tr>
        <td id="L103" class="blob-line-num js-line-number" data-line-number="103"></td>
        <td id="LC103" class="blob-line-code js-file-line">          <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L104" class="blob-line-num js-line-number" data-line-number="104"></td>
        <td id="LC104" class="blob-line-code js-file-line">        <span class="k">end</span><span class="o">.</span><span class="n">flatten</span><span class="o">.</span><span class="n">join</span><span class="p">(</span><span class="s2">&quot;&quot;</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L105" class="blob-line-num js-line-number" data-line-number="105"></td>
        <td id="LC105" class="blob-line-code js-file-line">        <span class="k">begin</span></td>
      </tr>
      <tr>
        <td id="L106" class="blob-line-num js-line-number" data-line-number="106"></td>
        <td id="LC106" class="blob-line-code js-file-line">          <span class="n">response</span> <span class="o">=</span> <span class="vi">@agent</span><span class="o">.</span><span class="n">post!</span><span class="p">(</span><span class="vi">@bulk_url</span><span class="p">,</span> <span class="ss">:body</span> <span class="o">=&gt;</span> <span class="n">body</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L107" class="blob-line-num js-line-number" data-line-number="107"></td>
        <td id="LC107" class="blob-line-code js-file-line">        <span class="k">rescue</span> <span class="no">EOFError</span></td>
      </tr>
      <tr>
        <td id="L108" class="blob-line-num js-line-number" data-line-number="108"></td>
        <td id="LC108" class="blob-line-code js-file-line">          <span class="vi">@logger</span><span class="o">.</span><span class="n">warn</span><span class="p">(</span><span class="s2">&quot;EOF while writing request or reading response header from elasticsearch&quot;</span><span class="p">,</span> <span class="ss">:host</span> <span class="o">=&gt;</span> <span class="vi">@host</span><span class="p">,</span> <span class="ss">:port</span> <span class="o">=&gt;</span> <span class="vi">@port</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L109" class="blob-line-num js-line-number" data-line-number="109"></td>
        <td id="LC109" class="blob-line-code js-file-line">          <span class="k">raise</span></td>
      </tr>
      <tr>
        <td id="L110" class="blob-line-num js-line-number" data-line-number="110"></td>
        <td id="LC110" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L111" class="blob-line-num js-line-number" data-line-number="111"></td>
        <td id="LC111" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L112" class="blob-line-num js-line-number" data-line-number="112"></td>
        <td id="LC112" class="blob-line-code js-file-line">        <span class="c1"># Consume the body for error checking</span></td>
      </tr>
      <tr>
        <td id="L113" class="blob-line-num js-line-number" data-line-number="113"></td>
        <td id="LC113" class="blob-line-code js-file-line">        <span class="c1"># This will also free up the connection for reuse.</span></td>
      </tr>
      <tr>
        <td id="L114" class="blob-line-num js-line-number" data-line-number="114"></td>
        <td id="LC114" class="blob-line-code js-file-line">        <span class="n">response_body</span> <span class="o">=</span> <span class="s2">&quot;&quot;</span></td>
      </tr>
      <tr>
        <td id="L115" class="blob-line-num js-line-number" data-line-number="115"></td>
        <td id="LC115" class="blob-line-code js-file-line">        <span class="k">begin</span></td>
      </tr>
      <tr>
        <td id="L116" class="blob-line-num js-line-number" data-line-number="116"></td>
        <td id="LC116" class="blob-line-code js-file-line">          <span class="n">response</span><span class="o">.</span><span class="n">read_body</span> <span class="p">{</span> <span class="o">|</span><span class="n">chunk</span><span class="o">|</span> <span class="n">response_body</span> <span class="o">+=</span> <span class="n">chunk</span> <span class="p">}</span></td>
      </tr>
      <tr>
        <td id="L117" class="blob-line-num js-line-number" data-line-number="117"></td>
        <td id="LC117" class="blob-line-code js-file-line">        <span class="k">rescue</span> <span class="no">EOFError</span></td>
      </tr>
      <tr>
        <td id="L118" class="blob-line-num js-line-number" data-line-number="118"></td>
        <td id="LC118" class="blob-line-code js-file-line">          <span class="vi">@logger</span><span class="o">.</span><span class="n">warn</span><span class="p">(</span><span class="s2">&quot;EOF while reading response body from elasticsearch&quot;</span><span class="p">,</span></td>
      </tr>
      <tr>
        <td id="L119" class="blob-line-num js-line-number" data-line-number="119"></td>
        <td id="LC119" class="blob-line-code js-file-line">                       <span class="ss">:url</span> <span class="o">=&gt;</span> <span class="vi">@bulk_url</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L120" class="blob-line-num js-line-number" data-line-number="120"></td>
        <td id="LC120" class="blob-line-code js-file-line">          <span class="k">raise</span></td>
      </tr>
      <tr>
        <td id="L121" class="blob-line-num js-line-number" data-line-number="121"></td>
        <td id="LC121" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L122" class="blob-line-num js-line-number" data-line-number="122"></td>
        <td id="LC122" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L123" class="blob-line-num js-line-number" data-line-number="123"></td>
        <td id="LC123" class="blob-line-code js-file-line">        <span class="k">if</span> <span class="n">response</span><span class="o">.</span><span class="n">status</span> <span class="o">!=</span> <span class="mi">200</span></td>
      </tr>
      <tr>
        <td id="L124" class="blob-line-num js-line-number" data-line-number="124"></td>
        <td id="LC124" class="blob-line-code js-file-line">          <span class="vi">@logger</span><span class="o">.</span><span class="n">error</span><span class="p">(</span><span class="s2">&quot;Error writing (bulk) to elasticsearch&quot;</span><span class="p">,</span></td>
      </tr>
      <tr>
        <td id="L125" class="blob-line-num js-line-number" data-line-number="125"></td>
        <td id="LC125" class="blob-line-code js-file-line">                        <span class="ss">:response</span> <span class="o">=&gt;</span> <span class="n">response</span><span class="p">,</span> <span class="ss">:response_body</span> <span class="o">=&gt;</span> <span class="n">response_body</span><span class="p">,</span></td>
      </tr>
      <tr>
        <td id="L126" class="blob-line-num js-line-number" data-line-number="126"></td>
        <td id="LC126" class="blob-line-code js-file-line">                        <span class="ss">:request_body</span> <span class="o">=&gt;</span> <span class="n">body</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L127" class="blob-line-num js-line-number" data-line-number="127"></td>
        <td id="LC127" class="blob-line-code js-file-line">          <span class="k">raise</span> <span class="s2">&quot;Non-OK response code from Elasticsearch: </span><span class="si">#{</span><span class="n">response</span><span class="o">.</span><span class="n">status</span><span class="si">}</span><span class="s2">&quot;</span></td>
      </tr>
      <tr>
        <td id="L128" class="blob-line-num js-line-number" data-line-number="128"></td>
        <td id="LC128" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L129" class="blob-line-num js-line-number" data-line-number="129"></td>
        <td id="LC129" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def bulk_ftw</span></td>
      </tr>
      <tr>
        <td id="L130" class="blob-line-num js-line-number" data-line-number="130"></td>
        <td id="LC130" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L131" class="blob-line-num js-line-number" data-line-number="131"></td>
        <td id="LC131" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">template_exists?</span><span class="p">(</span><span class="nb">name</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L132" class="blob-line-num js-line-number" data-line-number="132"></td>
        <td id="LC132" class="blob-line-code js-file-line">        <span class="vi">@client</span><span class="o">.</span><span class="n">indices</span><span class="o">.</span><span class="n">get_template</span><span class="p">(</span><span class="ss">:name</span> <span class="o">=&gt;</span> <span class="nb">name</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L133" class="blob-line-num js-line-number" data-line-number="133"></td>
        <td id="LC133" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="kp">true</span></td>
      </tr>
      <tr>
        <td id="L134" class="blob-line-num js-line-number" data-line-number="134"></td>
        <td id="LC134" class="blob-line-code js-file-line">      <span class="k">rescue</span> <span class="no">Elasticsearch</span><span class="o">::</span><span class="no">Transport</span><span class="o">::</span><span class="no">Transport</span><span class="o">::</span><span class="no">Errors</span><span class="o">::</span><span class="no">NotFound</span></td>
      </tr>
      <tr>
        <td id="L135" class="blob-line-num js-line-number" data-line-number="135"></td>
        <td id="LC135" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="kp">false</span></td>
      </tr>
      <tr>
        <td id="L136" class="blob-line-num js-line-number" data-line-number="136"></td>
        <td id="LC136" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def template_exists?</span></td>
      </tr>
      <tr>
        <td id="L137" class="blob-line-num js-line-number" data-line-number="137"></td>
        <td id="LC137" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L138" class="blob-line-num js-line-number" data-line-number="138"></td>
        <td id="LC138" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">template_put</span><span class="p">(</span><span class="nb">name</span><span class="p">,</span> <span class="n">template</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L139" class="blob-line-num js-line-number" data-line-number="139"></td>
        <td id="LC139" class="blob-line-code js-file-line">        <span class="vi">@client</span><span class="o">.</span><span class="n">indices</span><span class="o">.</span><span class="n">put_template</span><span class="p">(</span><span class="ss">:name</span> <span class="o">=&gt;</span> <span class="nb">name</span><span class="p">,</span> <span class="ss">:body</span> <span class="o">=&gt;</span> <span class="n">template</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L140" class="blob-line-num js-line-number" data-line-number="140"></td>
        <td id="LC140" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># template_put</span></td>
      </tr>
      <tr>
        <td id="L141" class="blob-line-num js-line-number" data-line-number="141"></td>
        <td id="LC141" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L142" class="blob-line-num js-line-number" data-line-number="142"></td>
        <td id="LC142" class="blob-line-code js-file-line">      <span class="kp">public</span><span class="p">(</span><span class="ss">:bulk</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L143" class="blob-line-num js-line-number" data-line-number="143"></td>
        <td id="LC143" class="blob-line-code js-file-line">    <span class="k">end</span> <span class="c1"># class HTTPClient</span></td>
      </tr>
      <tr>
        <td id="L144" class="blob-line-num js-line-number" data-line-number="144"></td>
        <td id="LC144" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L145" class="blob-line-num js-line-number" data-line-number="145"></td>
        <td id="LC145" class="blob-line-code js-file-line">    <span class="k">class</span> <span class="nc">NodeClient</span> <span class="o">&lt;</span> <span class="no">Base</span></td>
      </tr>
      <tr>
        <td id="L146" class="blob-line-num js-line-number" data-line-number="146"></td>
        <td id="LC146" class="blob-line-code js-file-line">      <span class="kp">private</span></td>
      </tr>
      <tr>
        <td id="L147" class="blob-line-num js-line-number" data-line-number="147"></td>
        <td id="LC147" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L148" class="blob-line-num js-line-number" data-line-number="148"></td>
        <td id="LC148" class="blob-line-code js-file-line">      <span class="no">DEFAULT_OPTIONS</span> <span class="o">=</span> <span class="p">{</span></td>
      </tr>
      <tr>
        <td id="L149" class="blob-line-num js-line-number" data-line-number="149"></td>
        <td id="LC149" class="blob-line-code js-file-line">        <span class="ss">:port</span> <span class="o">=&gt;</span> <span class="mi">9300</span><span class="p">,</span></td>
      </tr>
      <tr>
        <td id="L150" class="blob-line-num js-line-number" data-line-number="150"></td>
        <td id="LC150" class="blob-line-code js-file-line">      <span class="p">}</span></td>
      </tr>
      <tr>
        <td id="L151" class="blob-line-num js-line-number" data-line-number="151"></td>
        <td id="LC151" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L152" class="blob-line-num js-line-number" data-line-number="152"></td>
        <td id="LC152" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">initialize</span><span class="p">(</span><span class="n">options</span><span class="o">=</span><span class="p">{})</span></td>
      </tr>
      <tr>
        <td id="L153" class="blob-line-num js-line-number" data-line-number="153"></td>
        <td id="LC153" class="blob-line-code js-file-line">        <span class="k">super</span></td>
      </tr>
      <tr>
        <td id="L154" class="blob-line-num js-line-number" data-line-number="154"></td>
        <td id="LC154" class="blob-line-code js-file-line">        <span class="nb">require</span> <span class="s2">&quot;java&quot;</span></td>
      </tr>
      <tr>
        <td id="L155" class="blob-line-num js-line-number" data-line-number="155"></td>
        <td id="LC155" class="blob-line-code js-file-line">        <span class="vi">@options</span> <span class="o">=</span> <span class="no">DEFAULT_OPTIONS</span><span class="o">.</span><span class="n">merge</span><span class="p">(</span><span class="n">options</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L156" class="blob-line-num js-line-number" data-line-number="156"></td>
        <td id="LC156" class="blob-line-code js-file-line">        <span class="n">setup</span><span class="p">(</span><span class="vi">@options</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L157" class="blob-line-num js-line-number" data-line-number="157"></td>
        <td id="LC157" class="blob-line-code js-file-line">        <span class="vi">@client</span> <span class="o">=</span> <span class="n">client</span></td>
      </tr>
      <tr>
        <td id="L158" class="blob-line-num js-line-number" data-line-number="158"></td>
        <td id="LC158" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def initialize</span></td>
      </tr>
      <tr>
        <td id="L159" class="blob-line-num js-line-number" data-line-number="159"></td>
        <td id="LC159" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L160" class="blob-line-num js-line-number" data-line-number="160"></td>
        <td id="LC160" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">settings</span></td>
      </tr>
      <tr>
        <td id="L161" class="blob-line-num js-line-number" data-line-number="161"></td>
        <td id="LC161" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="vi">@settings</span></td>
      </tr>
      <tr>
        <td id="L162" class="blob-line-num js-line-number" data-line-number="162"></td>
        <td id="LC162" class="blob-line-code js-file-line">      <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L163" class="blob-line-num js-line-number" data-line-number="163"></td>
        <td id="LC163" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L164" class="blob-line-num js-line-number" data-line-number="164"></td>
        <td id="LC164" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">setup</span><span class="p">(</span><span class="n">options</span><span class="o">=</span><span class="p">{})</span></td>
      </tr>
      <tr>
        <td id="L165" class="blob-line-num js-line-number" data-line-number="165"></td>
        <td id="LC165" class="blob-line-code js-file-line">        <span class="vi">@settings</span> <span class="o">=</span> <span class="n">org</span><span class="o">.</span><span class="n">elasticsearch</span><span class="o">.</span><span class="n">common</span><span class="o">.</span><span class="n">settings</span><span class="o">.</span><span class="n">ImmutableSettings</span><span class="o">.</span><span class="n">settingsBuilder</span></td>
      </tr>
      <tr>
        <td id="L166" class="blob-line-num js-line-number" data-line-number="166"></td>
        <td id="LC166" class="blob-line-code js-file-line">        <span class="k">if</span> <span class="n">options</span><span class="o">[</span><span class="ss">:host</span><span class="o">]</span></td>
      </tr>
      <tr>
        <td id="L167" class="blob-line-num js-line-number" data-line-number="167"></td>
        <td id="LC167" class="blob-line-code js-file-line">          <span class="vi">@settings</span><span class="o">.</span><span class="n">put</span><span class="p">(</span><span class="s2">&quot;discovery.zen.ping.multicast.enabled&quot;</span><span class="p">,</span> <span class="kp">false</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L168" class="blob-line-num js-line-number" data-line-number="168"></td>
        <td id="LC168" class="blob-line-code js-file-line">          <span class="vi">@settings</span><span class="o">.</span><span class="n">put</span><span class="p">(</span><span class="s2">&quot;discovery.zen.ping.unicast.hosts&quot;</span><span class="p">,</span> <span class="n">hosts</span><span class="p">(</span><span class="n">options</span><span class="p">))</span></td>
      </tr>
      <tr>
        <td id="L169" class="blob-line-num js-line-number" data-line-number="169"></td>
        <td id="LC169" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L170" class="blob-line-num js-line-number" data-line-number="170"></td>
        <td id="LC170" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L171" class="blob-line-num js-line-number" data-line-number="171"></td>
        <td id="LC171" class="blob-line-code js-file-line">        <span class="vi">@settings</span><span class="o">.</span><span class="n">put</span><span class="p">(</span><span class="s2">&quot;node.client&quot;</span><span class="p">,</span> <span class="kp">true</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L172" class="blob-line-num js-line-number" data-line-number="172"></td>
        <td id="LC172" class="blob-line-code js-file-line">        <span class="vi">@settings</span><span class="o">.</span><span class="n">put</span><span class="p">(</span><span class="s2">&quot;http.enabled&quot;</span><span class="p">,</span> <span class="kp">false</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L173" class="blob-line-num js-line-number" data-line-number="173"></td>
        <td id="LC173" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L174" class="blob-line-num js-line-number" data-line-number="174"></td>
        <td id="LC174" class="blob-line-code js-file-line">        <span class="k">if</span> <span class="n">options</span><span class="o">[</span><span class="ss">:client_settings</span><span class="o">]</span></td>
      </tr>
      <tr>
        <td id="L175" class="blob-line-num js-line-number" data-line-number="175"></td>
        <td id="LC175" class="blob-line-code js-file-line">          <span class="n">options</span><span class="o">[</span><span class="ss">:client_settings</span><span class="o">].</span><span class="n">each</span> <span class="k">do</span> <span class="o">|</span><span class="n">key</span><span class="p">,</span> <span class="n">value</span><span class="o">|</span></td>
      </tr>
      <tr>
        <td id="L176" class="blob-line-num js-line-number" data-line-number="176"></td>
        <td id="LC176" class="blob-line-code js-file-line">            <span class="vi">@settings</span><span class="o">.</span><span class="n">put</span><span class="p">(</span><span class="n">key</span><span class="p">,</span> <span class="n">value</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L177" class="blob-line-num js-line-number" data-line-number="177"></td>
        <td id="LC177" class="blob-line-code js-file-line">          <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L178" class="blob-line-num js-line-number" data-line-number="178"></td>
        <td id="LC178" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L179" class="blob-line-num js-line-number" data-line-number="179"></td>
        <td id="LC179" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L180" class="blob-line-num js-line-number" data-line-number="180"></td>
        <td id="LC180" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="vi">@settings</span></td>
      </tr>
      <tr>
        <td id="L181" class="blob-line-num js-line-number" data-line-number="181"></td>
        <td id="LC181" class="blob-line-code js-file-line">      <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L182" class="blob-line-num js-line-number" data-line-number="182"></td>
        <td id="LC182" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L183" class="blob-line-num js-line-number" data-line-number="183"></td>
        <td id="LC183" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">hosts</span><span class="p">(</span><span class="n">options</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L184" class="blob-line-num js-line-number" data-line-number="184"></td>
        <td id="LC184" class="blob-line-code js-file-line">        <span class="k">if</span> <span class="n">options</span><span class="o">[</span><span class="ss">:port</span><span class="o">].</span><span class="n">to_s</span> <span class="o">=~</span> <span class="sr">/^\d+-\d+$/</span></td>
      </tr>
      <tr>
        <td id="L185" class="blob-line-num js-line-number" data-line-number="185"></td>
        <td id="LC185" class="blob-line-code js-file-line">          <span class="c1"># port ranges are &#39;host[port1-port2]&#39; according to</span></td>
      </tr>
      <tr>
        <td id="L186" class="blob-line-num js-line-number" data-line-number="186"></td>
        <td id="LC186" class="blob-line-code js-file-line">          <span class="c1"># http://www.elasticsearch.org/guide/reference/modules/discovery/zen/</span></td>
      </tr>
      <tr>
        <td id="L187" class="blob-line-num js-line-number" data-line-number="187"></td>
        <td id="LC187" class="blob-line-code js-file-line">          <span class="c1"># However, it seems to only query the first port.</span></td>
      </tr>
      <tr>
        <td id="L188" class="blob-line-num js-line-number" data-line-number="188"></td>
        <td id="LC188" class="blob-line-code js-file-line">          <span class="c1"># So generate our own list of unicast hosts to scan.</span></td>
      </tr>
      <tr>
        <td id="L189" class="blob-line-num js-line-number" data-line-number="189"></td>
        <td id="LC189" class="blob-line-code js-file-line">          <span class="n">range</span> <span class="o">=</span> <span class="no">Range</span><span class="o">.</span><span class="n">new</span><span class="p">(</span><span class="o">*</span><span class="n">options</span><span class="o">[</span><span class="ss">:port</span><span class="o">].</span><span class="n">split</span><span class="p">(</span><span class="s2">&quot;-&quot;</span><span class="p">))</span></td>
      </tr>
      <tr>
        <td id="L190" class="blob-line-num js-line-number" data-line-number="190"></td>
        <td id="LC190" class="blob-line-code js-file-line">          <span class="k">return</span> <span class="n">range</span><span class="o">.</span><span class="n">collect</span> <span class="p">{</span> <span class="o">|</span><span class="nb">p</span><span class="o">|</span> <span class="s2">&quot;</span><span class="si">#{</span><span class="n">options</span><span class="o">[</span><span class="ss">:host</span><span class="o">]</span><span class="si">}</span><span class="s2">:</span><span class="si">#{</span><span class="nb">p</span><span class="si">}</span><span class="s2">&quot;</span> <span class="p">}</span><span class="o">.</span><span class="n">join</span><span class="p">(</span><span class="s2">&quot;,&quot;</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L191" class="blob-line-num js-line-number" data-line-number="191"></td>
        <td id="LC191" class="blob-line-code js-file-line">        <span class="k">else</span></td>
      </tr>
      <tr>
        <td id="L192" class="blob-line-num js-line-number" data-line-number="192"></td>
        <td id="LC192" class="blob-line-code js-file-line">          <span class="k">return</span> <span class="s2">&quot;</span><span class="si">#{</span><span class="n">options</span><span class="o">[</span><span class="ss">:host</span><span class="o">]</span><span class="si">}</span><span class="s2">:</span><span class="si">#{</span><span class="n">options</span><span class="o">[</span><span class="ss">:port</span><span class="o">]</span><span class="si">}</span><span class="s2">&quot;</span></td>
      </tr>
      <tr>
        <td id="L193" class="blob-line-num js-line-number" data-line-number="193"></td>
        <td id="LC193" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L194" class="blob-line-num js-line-number" data-line-number="194"></td>
        <td id="LC194" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def hosts</span></td>
      </tr>
      <tr>
        <td id="L195" class="blob-line-num js-line-number" data-line-number="195"></td>
        <td id="LC195" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L196" class="blob-line-num js-line-number" data-line-number="196"></td>
        <td id="LC196" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">build_client</span><span class="p">(</span><span class="n">options</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L197" class="blob-line-num js-line-number" data-line-number="197"></td>
        <td id="LC197" class="blob-line-code js-file-line">        <span class="n">nodebuilder</span> <span class="o">=</span> <span class="n">org</span><span class="o">.</span><span class="n">elasticsearch</span><span class="o">.</span><span class="n">node</span><span class="o">.</span><span class="n">NodeBuilder</span><span class="o">.</span><span class="n">nodeBuilder</span></td>
      </tr>
      <tr>
        <td id="L198" class="blob-line-num js-line-number" data-line-number="198"></td>
        <td id="LC198" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="n">nodebuilder</span><span class="o">.</span><span class="n">settings</span><span class="p">(</span><span class="vi">@settings</span><span class="p">)</span><span class="o">.</span><span class="n">node</span><span class="o">.</span><span class="n">client</span></td>
      </tr>
      <tr>
        <td id="L199" class="blob-line-num js-line-number" data-line-number="199"></td>
        <td id="LC199" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def build_client</span></td>
      </tr>
      <tr>
        <td id="L200" class="blob-line-num js-line-number" data-line-number="200"></td>
        <td id="LC200" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L201" class="blob-line-num js-line-number" data-line-number="201"></td>
        <td id="LC201" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">bulk</span><span class="p">(</span><span class="n">actions</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L202" class="blob-line-num js-line-number" data-line-number="202"></td>
        <td id="LC202" class="blob-line-code js-file-line">        <span class="c1"># Actions an array of [ action, action_metadata, source ]</span></td>
      </tr>
      <tr>
        <td id="L203" class="blob-line-num js-line-number" data-line-number="203"></td>
        <td id="LC203" class="blob-line-code js-file-line">        <span class="n">prep</span> <span class="o">=</span> <span class="vi">@client</span><span class="o">.</span><span class="n">prepareBulk</span></td>
      </tr>
      <tr>
        <td id="L204" class="blob-line-num js-line-number" data-line-number="204"></td>
        <td id="LC204" class="blob-line-code js-file-line">        <span class="n">actions</span><span class="o">.</span><span class="n">each</span> <span class="k">do</span> <span class="o">|</span><span class="n">action</span><span class="p">,</span> <span class="n">args</span><span class="p">,</span> <span class="n">source</span><span class="o">|</span></td>
      </tr>
      <tr>
        <td id="L205" class="blob-line-num js-line-number" data-line-number="205"></td>
        <td id="LC205" class="blob-line-code js-file-line">          <span class="n">prep</span><span class="o">.</span><span class="n">add</span><span class="p">(</span><span class="n">build_request</span><span class="p">(</span><span class="n">action</span><span class="p">,</span> <span class="n">args</span><span class="p">,</span> <span class="n">source</span><span class="p">))</span></td>
      </tr>
      <tr>
        <td id="L206" class="blob-line-num js-line-number" data-line-number="206"></td>
        <td id="LC206" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L207" class="blob-line-num js-line-number" data-line-number="207"></td>
        <td id="LC207" class="blob-line-code js-file-line">        <span class="n">response</span> <span class="o">=</span> <span class="n">prep</span><span class="o">.</span><span class="n">execute</span><span class="o">.</span><span class="n">actionGet</span><span class="p">()</span></td>
      </tr>
      <tr>
        <td id="L208" class="blob-line-num js-line-number" data-line-number="208"></td>
        <td id="LC208" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L209" class="blob-line-num js-line-number" data-line-number="209"></td>
        <td id="LC209" class="blob-line-code js-file-line">        <span class="c1"># TODO(sissel): What format should the response be in?</span></td>
      </tr>
      <tr>
        <td id="L210" class="blob-line-num js-line-number" data-line-number="210"></td>
        <td id="LC210" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def bulk</span></td>
      </tr>
      <tr>
        <td id="L211" class="blob-line-num js-line-number" data-line-number="211"></td>
        <td id="LC211" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L212" class="blob-line-num js-line-number" data-line-number="212"></td>
        <td id="LC212" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">build_request</span><span class="p">(</span><span class="n">action</span><span class="p">,</span> <span class="n">args</span><span class="p">,</span> <span class="n">source</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L213" class="blob-line-num js-line-number" data-line-number="213"></td>
        <td id="LC213" class="blob-line-code js-file-line">        <span class="k">case</span> <span class="n">action</span></td>
      </tr>
      <tr>
        <td id="L214" class="blob-line-num js-line-number" data-line-number="214"></td>
        <td id="LC214" class="blob-line-code js-file-line">          <span class="k">when</span> <span class="s2">&quot;index&quot;</span></td>
      </tr>
      <tr>
        <td id="L215" class="blob-line-num js-line-number" data-line-number="215"></td>
        <td id="LC215" class="blob-line-code js-file-line">            <span class="n">request</span> <span class="o">=</span> <span class="n">org</span><span class="o">.</span><span class="n">elasticsearch</span><span class="o">.</span><span class="n">action</span><span class="o">.</span><span class="n">index</span><span class="o">.</span><span class="n">IndexRequest</span><span class="o">.</span><span class="n">new</span><span class="p">(</span><span class="n">args</span><span class="o">[</span><span class="ss">:_index</span><span class="o">]</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L216" class="blob-line-num js-line-number" data-line-number="216"></td>
        <td id="LC216" class="blob-line-code js-file-line">            <span class="n">request</span><span class="o">.</span><span class="n">id</span><span class="p">(</span><span class="n">args</span><span class="o">[</span><span class="ss">:_id</span><span class="o">]</span><span class="p">)</span> <span class="k">if</span> <span class="n">args</span><span class="o">[</span><span class="ss">:_id</span><span class="o">]</span></td>
      </tr>
      <tr>
        <td id="L217" class="blob-line-num js-line-number" data-line-number="217"></td>
        <td id="LC217" class="blob-line-code js-file-line">            <span class="n">request</span><span class="o">.</span><span class="n">source</span><span class="p">(</span><span class="n">source</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L218" class="blob-line-num js-line-number" data-line-number="218"></td>
        <td id="LC218" class="blob-line-code js-file-line">          <span class="k">when</span> <span class="s2">&quot;delete&quot;</span></td>
      </tr>
      <tr>
        <td id="L219" class="blob-line-num js-line-number" data-line-number="219"></td>
        <td id="LC219" class="blob-line-code js-file-line">            <span class="n">request</span> <span class="o">=</span> <span class="n">org</span><span class="o">.</span><span class="n">elasticsearch</span><span class="o">.</span><span class="n">action</span><span class="o">.</span><span class="n">delete</span><span class="o">.</span><span class="n">DeleteRequest</span><span class="o">.</span><span class="n">new</span><span class="p">(</span><span class="n">args</span><span class="o">[</span><span class="ss">:_index</span><span class="o">]</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L220" class="blob-line-num js-line-number" data-line-number="220"></td>
        <td id="LC220" class="blob-line-code js-file-line">            <span class="n">request</span><span class="o">.</span><span class="n">id</span><span class="p">(</span><span class="n">args</span><span class="o">[</span><span class="ss">:_id</span><span class="o">]</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L221" class="blob-line-num js-line-number" data-line-number="221"></td>
        <td id="LC221" class="blob-line-code js-file-line">          <span class="c1">#when &quot;update&quot;</span></td>
      </tr>
      <tr>
        <td id="L222" class="blob-line-num js-line-number" data-line-number="222"></td>
        <td id="LC222" class="blob-line-code js-file-line">          <span class="c1">#when &quot;create&quot;</span></td>
      </tr>
      <tr>
        <td id="L223" class="blob-line-num js-line-number" data-line-number="223"></td>
        <td id="LC223" class="blob-line-code js-file-line">        <span class="k">end</span> <span class="c1"># case action</span></td>
      </tr>
      <tr>
        <td id="L224" class="blob-line-num js-line-number" data-line-number="224"></td>
        <td id="LC224" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L225" class="blob-line-num js-line-number" data-line-number="225"></td>
        <td id="LC225" class="blob-line-code js-file-line">        <span class="n">request</span><span class="o">.</span><span class="n">type</span><span class="p">(</span><span class="n">args</span><span class="o">[</span><span class="ss">:_type</span><span class="o">]</span><span class="p">)</span> <span class="k">if</span> <span class="n">args</span><span class="o">[</span><span class="ss">:_type</span><span class="o">]</span></td>
      </tr>
      <tr>
        <td id="L226" class="blob-line-num js-line-number" data-line-number="226"></td>
        <td id="LC226" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="n">request</span></td>
      </tr>
      <tr>
        <td id="L227" class="blob-line-num js-line-number" data-line-number="227"></td>
        <td id="LC227" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def build_request</span></td>
      </tr>
      <tr>
        <td id="L228" class="blob-line-num js-line-number" data-line-number="228"></td>
        <td id="LC228" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L229" class="blob-line-num js-line-number" data-line-number="229"></td>
        <td id="LC229" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">template_exists?</span><span class="p">(</span><span class="nb">name</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L230" class="blob-line-num js-line-number" data-line-number="230"></td>
        <td id="LC230" class="blob-line-code js-file-line">        <span class="n">request</span> <span class="o">=</span> <span class="n">org</span><span class="o">.</span><span class="n">elasticsearch</span><span class="o">.</span><span class="n">action</span><span class="o">.</span><span class="n">admin</span><span class="o">.</span><span class="n">indices</span><span class="o">.</span><span class="n">template</span><span class="o">.</span><span class="n">get</span><span class="o">.</span><span class="n">GetIndexTemplatesRequestBuilder</span><span class="o">.</span><span class="n">new</span><span class="p">(</span><span class="vi">@client</span><span class="o">.</span><span class="n">admin</span><span class="o">.</span><span class="n">indices</span><span class="p">,</span> <span class="nb">name</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L231" class="blob-line-num js-line-number" data-line-number="231"></td>
        <td id="LC231" class="blob-line-code js-file-line">        <span class="n">response</span> <span class="o">=</span> <span class="n">request</span><span class="o">.</span><span class="n">get</span></td>
      </tr>
      <tr>
        <td id="L232" class="blob-line-num js-line-number" data-line-number="232"></td>
        <td id="LC232" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="o">!</span><span class="n">response</span><span class="o">.</span><span class="n">getIndexTemplates</span><span class="o">.</span><span class="n">isEmpty</span></td>
      </tr>
      <tr>
        <td id="L233" class="blob-line-num js-line-number" data-line-number="233"></td>
        <td id="LC233" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def template_exists?</span></td>
      </tr>
      <tr>
        <td id="L234" class="blob-line-num js-line-number" data-line-number="234"></td>
        <td id="LC234" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L235" class="blob-line-num js-line-number" data-line-number="235"></td>
        <td id="LC235" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">template_put</span><span class="p">(</span><span class="nb">name</span><span class="p">,</span> <span class="n">template</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L236" class="blob-line-num js-line-number" data-line-number="236"></td>
        <td id="LC236" class="blob-line-code js-file-line">        <span class="n">request</span> <span class="o">=</span> <span class="n">org</span><span class="o">.</span><span class="n">elasticsearch</span><span class="o">.</span><span class="n">action</span><span class="o">.</span><span class="n">admin</span><span class="o">.</span><span class="n">indices</span><span class="o">.</span><span class="n">template</span><span class="o">.</span><span class="n">put</span><span class="o">.</span><span class="n">PutIndexTemplateRequestBuilder</span><span class="o">.</span><span class="n">new</span><span class="p">(</span><span class="vi">@client</span><span class="o">.</span><span class="n">admin</span><span class="o">.</span><span class="n">indices</span><span class="p">,</span> <span class="nb">name</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L237" class="blob-line-num js-line-number" data-line-number="237"></td>
        <td id="LC237" class="blob-line-code js-file-line">        <span class="n">request</span><span class="o">.</span><span class="n">setSource</span><span class="p">(</span><span class="no">LogStash</span><span class="o">::</span><span class="no">Json</span><span class="o">.</span><span class="n">dump</span><span class="p">(</span><span class="n">template</span><span class="p">))</span></td>
      </tr>
      <tr>
        <td id="L238" class="blob-line-num js-line-number" data-line-number="238"></td>
        <td id="LC238" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L239" class="blob-line-num js-line-number" data-line-number="239"></td>
        <td id="LC239" class="blob-line-code js-file-line">        <span class="c1"># execute the request and get the response, if it fails, we&#39;ll get an exception.</span></td>
      </tr>
      <tr>
        <td id="L240" class="blob-line-num js-line-number" data-line-number="240"></td>
        <td id="LC240" class="blob-line-code js-file-line">        <span class="n">request</span><span class="o">.</span><span class="n">get</span></td>
      </tr>
      <tr>
        <td id="L241" class="blob-line-num js-line-number" data-line-number="241"></td>
        <td id="LC241" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># template_put</span></td>
      </tr>
      <tr>
        <td id="L242" class="blob-line-num js-line-number" data-line-number="242"></td>
        <td id="LC242" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L243" class="blob-line-num js-line-number" data-line-number="243"></td>
        <td id="LC243" class="blob-line-code js-file-line">      <span class="kp">public</span><span class="p">(</span><span class="ss">:initialize</span><span class="p">,</span> <span class="ss">:bulk</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L244" class="blob-line-num js-line-number" data-line-number="244"></td>
        <td id="LC244" class="blob-line-code js-file-line">    <span class="k">end</span> <span class="c1"># class NodeClient</span></td>
      </tr>
      <tr>
        <td id="L245" class="blob-line-num js-line-number" data-line-number="245"></td>
        <td id="LC245" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L246" class="blob-line-num js-line-number" data-line-number="246"></td>
        <td id="LC246" class="blob-line-code js-file-line">    <span class="k">class</span> <span class="nc">TransportClient</span> <span class="o">&lt;</span> <span class="no">NodeClient</span></td>
      </tr>
      <tr>
        <td id="L247" class="blob-line-num js-line-number" data-line-number="247"></td>
        <td id="LC247" class="blob-line-code js-file-line">      <span class="kp">private</span></td>
      </tr>
      <tr>
        <td id="L248" class="blob-line-num js-line-number" data-line-number="248"></td>
        <td id="LC248" class="blob-line-code js-file-line">      <span class="k">def</span> <span class="nf">build_client</span><span class="p">(</span><span class="n">options</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L249" class="blob-line-num js-line-number" data-line-number="249"></td>
        <td id="LC249" class="blob-line-code js-file-line">        <span class="n">client</span> <span class="o">=</span> <span class="n">org</span><span class="o">.</span><span class="n">elasticsearch</span><span class="o">.</span><span class="n">client</span><span class="o">.</span><span class="n">transport</span><span class="o">.</span><span class="n">TransportClient</span><span class="o">.</span><span class="n">new</span><span class="p">(</span><span class="n">settings</span><span class="o">.</span><span class="n">build</span><span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L250" class="blob-line-num js-line-number" data-line-number="250"></td>
        <td id="LC250" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L251" class="blob-line-num js-line-number" data-line-number="251"></td>
        <td id="LC251" class="blob-line-code js-file-line">        <span class="k">if</span> <span class="n">options</span><span class="o">[</span><span class="ss">:host</span><span class="o">]</span></td>
      </tr>
      <tr>
        <td id="L252" class="blob-line-num js-line-number" data-line-number="252"></td>
        <td id="LC252" class="blob-line-code js-file-line">          <span class="n">client</span><span class="o">.</span><span class="n">addTransportAddress</span><span class="p">(</span></td>
      </tr>
      <tr>
        <td id="L253" class="blob-line-num js-line-number" data-line-number="253"></td>
        <td id="LC253" class="blob-line-code js-file-line">            <span class="n">org</span><span class="o">.</span><span class="n">elasticsearch</span><span class="o">.</span><span class="n">common</span><span class="o">.</span><span class="n">transport</span><span class="o">.</span><span class="n">InetSocketTransportAddress</span><span class="o">.</span><span class="n">new</span><span class="p">(</span></td>
      </tr>
      <tr>
        <td id="L254" class="blob-line-num js-line-number" data-line-number="254"></td>
        <td id="LC254" class="blob-line-code js-file-line">              <span class="n">options</span><span class="o">[</span><span class="ss">:host</span><span class="o">]</span><span class="p">,</span> <span class="n">options</span><span class="o">[</span><span class="ss">:port</span><span class="o">].</span><span class="n">to_i</span></td>
      </tr>
      <tr>
        <td id="L255" class="blob-line-num js-line-number" data-line-number="255"></td>
        <td id="LC255" class="blob-line-code js-file-line">            <span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L256" class="blob-line-num js-line-number" data-line-number="256"></td>
        <td id="LC256" class="blob-line-code js-file-line">          <span class="p">)</span></td>
      </tr>
      <tr>
        <td id="L257" class="blob-line-num js-line-number" data-line-number="257"></td>
        <td id="LC257" class="blob-line-code js-file-line">        <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L258" class="blob-line-num js-line-number" data-line-number="258"></td>
        <td id="LC258" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L259" class="blob-line-num js-line-number" data-line-number="259"></td>
        <td id="LC259" class="blob-line-code js-file-line">        <span class="k">return</span> <span class="n">client</span></td>
      </tr>
      <tr>
        <td id="L260" class="blob-line-num js-line-number" data-line-number="260"></td>
        <td id="LC260" class="blob-line-code js-file-line">      <span class="k">end</span> <span class="c1"># def build_client</span></td>
      </tr>
      <tr>
        <td id="L261" class="blob-line-num js-line-number" data-line-number="261"></td>
        <td id="LC261" class="blob-line-code js-file-line">    <span class="k">end</span> <span class="c1"># class TransportClient</span></td>
      </tr>
      <tr>
        <td id="L262" class="blob-line-num js-line-number" data-line-number="262"></td>
        <td id="LC262" class="blob-line-code js-file-line">  <span class="k">end</span> <span class="c1"># module Protocols</span></td>
      </tr>
      <tr>
        <td id="L263" class="blob-line-num js-line-number" data-line-number="263"></td>
        <td id="LC263" class="blob-line-code js-file-line">
</td>
      </tr>
      <tr>
        <td id="L264" class="blob-line-num js-line-number" data-line-number="264"></td>
        <td id="LC264" class="blob-line-code js-file-line">  <span class="k">module</span> <span class="nn">Requests</span></td>
      </tr>
      <tr>
        <td id="L265" class="blob-line-num js-line-number" data-line-number="265"></td>
        <td id="LC265" class="blob-line-code js-file-line">    <span class="k">class</span> <span class="nc">GetIndexTemplates</span><span class="p">;</span> <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L266" class="blob-line-num js-line-number" data-line-number="266"></td>
        <td id="LC266" class="blob-line-code js-file-line">    <span class="k">class</span> <span class="nc">Bulk</span><span class="p">;</span> <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L267" class="blob-line-num js-line-number" data-line-number="267"></td>
        <td id="LC267" class="blob-line-code js-file-line">    <span class="k">class</span> <span class="nc">Index</span><span class="p">;</span> <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L268" class="blob-line-num js-line-number" data-line-number="268"></td>
        <td id="LC268" class="blob-line-code js-file-line">    <span class="k">class</span> <span class="nc">Delete</span><span class="p">;</span> <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L269" class="blob-line-num js-line-number" data-line-number="269"></td>
        <td id="LC269" class="blob-line-code js-file-line">  <span class="k">end</span></td>
      </tr>
      <tr>
        <td id="L270" class="blob-line-num js-line-number" data-line-number="270"></td>
        <td id="LC270" class="blob-line-code js-file-line"><span class="k">end</span></td>
      </tr>
</table>

  </div>

  </div>
</div>

<a href="#jump-to-line" rel="facebox[.linejump]" data-hotkey="l" style="display:none">Jump to Line</a>
<div id="jump-to-line" style="display:none">
  <form accept-charset="UTF-8" class="js-jump-to-line-form">
    <input class="linejump-input js-jump-to-line-field" type="text" placeholder="Jump to line&hellip;" autofocus>
    <button type="submit" class="button">Go</button>
  </form>
</div>

        </div>

      </div><!-- /.repo-container -->
      <div class="modal-backdrop"></div>
    </div><!-- /.container -->
  </div><!-- /.site -->


    </div><!-- /.wrapper -->

      <div class="container">
  <div class="site-footer">
    <ul class="site-footer-links right">
      <li><a href="https://status.github.com/">Status</a></li>
      <li><a href="http://developer.github.com">API</a></li>
      <li><a href="http://training.github.com">Training</a></li>
      <li><a href="http://shop.github.com">Shop</a></li>
      <li><a href="/blog">Blog</a></li>
      <li><a href="/about">About</a></li>

    </ul>

    <a href="/" aria-label="Homepage">
      <span class="mega-octicon octicon-mark-github" title="GitHub"></span>
    </a>

    <ul class="site-footer-links">
      <li>&copy; 2014 <span title="0.02425s from github-fe131-cp1-prd.iad.github.net">GitHub</span>, Inc.</li>
        <li><a href="/site/terms">Terms</a></li>
        <li><a href="/site/privacy">Privacy</a></li>
        <li><a href="/security">Security</a></li>
        <li><a href="/contact">Contact</a></li>
    </ul>
  </div><!-- /.site-footer -->
</div><!-- /.container -->


    <div class="fullscreen-overlay js-fullscreen-overlay" id="fullscreen_overlay">
  <div class="fullscreen-container js-suggester-container">
    <div class="textarea-wrap">
      <textarea name="fullscreen-contents" id="fullscreen-contents" class="fullscreen-contents js-fullscreen-contents js-suggester-field" placeholder=""></textarea>
    </div>
  </div>
  <div class="fullscreen-sidebar">
    <a href="#" class="exit-fullscreen js-exit-fullscreen tooltipped tooltipped-w" aria-label="Exit Zen Mode">
      <span class="mega-octicon octicon-screen-normal"></span>
    </a>
    <a href="#" class="theme-switcher js-theme-switcher tooltipped tooltipped-w"
      aria-label="Switch themes">
      <span class="octicon octicon-color-mode"></span>
    </a>
  </div>
</div>



    <div id="ajax-error-message" class="flash flash-error">
      <span class="octicon octicon-alert"></span>
      <a href="#" class="octicon octicon-x close js-ajax-error-dismiss" aria-label="Dismiss error"></a>
      Something went wrong with that request. Please try again.
    </div>


      <script crossorigin="anonymous" src="https://assets-cdn.github.com/assets/frameworks-12d5fda141e78e513749dddbc56445fe172cbd9a.js" type="text/javascript"></script>
      <script async="async" crossorigin="anonymous" src="https://assets-cdn.github.com/assets/github-f8cf379f177c2fd3562514979aef2b0ea1ccc9a2.js" type="text/javascript"></script>
      
      
        <script async src="https://www.google-analytics.com/analytics.js"></script>
  </body>
</html>

