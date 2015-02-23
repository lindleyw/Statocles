
use Statocles::Base 'Test';
use Statocles::Site;
use Statocles::Theme;
use Statocles::Store::File;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my ( $site, $build_dir, $deploy_dir ) = build_test_site_apps( $SHARE_DIR );

sub test_page_content {
    my ( $site, $page, $dir ) = @_;
    my $path = $dir->child( $page->path );
    my $got_dom = Mojo::DOM->new( $path->slurp );

    if ( $got_dom->at('title') ) {
        like $got_dom->at('title')->text, qr{@{[$site->title]}}, 'page contains site title ' . $site->title;
    }
}

subtest 'build' => sub {
    $site->build;

    for my $page ( $site->app( 'blog' )->pages, $site->app( 'static' )->pages ) {
        ok $build_dir->child( $page->path )->exists, $page->path . ' built';
        ok !$deploy_dir->child( $page->path )->exists, $page->path . ' not deployed yet';
    }

    subtest 'check static content' => sub {
        for my $page ( $site->app( 'static' )->pages ) {
            my $fh = $page->render;
            my $content = do { local $/; <$fh> };
            ok $build_dir->child( $page->path )->slurp_raw eq $content,
                $page->path . ' content is correct';
            ok !$deploy_dir->child( $page->path )->exists,
                $page->path . ' is not deployed';
        }
    };

    subtest 'check theme' => sub {
        my $iter = $site->theme->store->find_files;
        while ( my $theme_file = $iter->() ) {
            ok $build_dir->child( 'theme', $theme_file )->exists,
                'theme file ' . $theme_file . 'exists in build dir';
            ok !$deploy_dir->child( 'theme', $theme_file )->exists,
                'theme file ' . $theme_file . 'not in deploy dir';
        }
    };

};

subtest 'deploy' => sub {
    $site->deploy;

    for my $page ( $site->app( 'blog' )->pages, $site->app( 'static' )->pages ) {
        ok $build_dir->child( $page->path )->exists, $page->path . ' built';
        ok $deploy_dir->child( $page->path )->exists, $page->path . ' deployed';
    }

    subtest 'check static content' => sub {
        for my $page ( $site->app( 'static' )->pages ) {
            my $fh = $page->render;
            my $content = do { local $/; <$fh> };
            ok $deploy_dir->child( $page->path )->slurp_raw eq $content,
                $page->path . ' content is correct';
        }
    };

    subtest 'check theme' => sub {
        my $iter = $site->theme->store->find_files;
        while ( my $theme_file = $iter->() ) {
            ok $deploy_dir->child( 'theme', $theme_file )->exists,
                'theme file ' . $theme_file . 'exists in deploy dir';
        }
    };

};

subtest 'base URL with folder rewrites content' => sub {
    my ( $site, $build_dir, $deploy_dir ) = build_test_site_apps(
        $SHARE_DIR,
        deploy => {
            base_url => 'http://example.com/deploy',
        },
    );

    subtest 'build' => sub {
        $site->build;

        for my $page ( $site->app( 'blog' )->pages ) {
            subtest 'page content: ' . $page->path
                => \&test_page_content, $site, $page, $build_dir;
            ok !$deploy_dir->child( $page->path )->exists, 'not deployed yet';
        }

        subtest 'check static content' => sub {
            for my $page ( $site->app( 'static' )->pages ) {
                my $fh = $page->render;
                my $content = do { local $/; <$fh> };
                is $build_dir->child( $page->path )->slurp_raw, $content,
                    $page->path . ' content is correct';
            }
        };

    };

    subtest 'deploy' => sub {
        $site->deploy;

        for my $page ( $site->app( 'blog' )->pages ) {
            subtest 'page content: ' . $page->path
                => \&test_page_content, $site, $page, $deploy_dir;
        }

        subtest 'check static content' => sub {
            for my $page ( $site->app( 'static' )->pages ) {
                my $fh = $page->render;
                my $content = do { local $/; <$fh> };
                is $deploy_dir->child( $page->path )->slurp_raw, $content,
                    $page->path . ' content is correct';
            }
        };

    };
};

done_testing;
