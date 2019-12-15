# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6

#IUSE="net45 debug developer"
#USE_DOTNET="net45"

inherit systemd user
#inherit systemd user git-r3

DESCRIPTION="The Free Software Media System"
HOMEPAGE="https://github.com/jellyfin/jellyfin"

#EGIT_REPO_URI="https://github.com/${PN}/${PN}.git"
#EGIT_COMMIT="v${PV}"
#EGIT_SUBMODULES=( jellyfin-web )

SRC_URI="https://github.com/${PN}/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
		https://github.com/${PN}/${PN}-web/archive/v${PV}.tar.gz -> ${PN}-web-${PV}.tar.gz"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"
#IUSE="system-ffmpeg"

DEPEND="!media-tv/jellyfin-bin"
RDEPEND="${DEPEND}
		media-video/ffmpeg[fontconfig,gmp,libass,libdrm,truetype,fribidi,vorbis,vdpau,vaapi,x264,x265,webp,bluray,zvbi,mp3,opus,theora]
		sys-process/at
		dev-db/sqlite:3
		media-libs/fontconfig
		media-libs/freetype
		dev-util/lttng-ust
		app-crypt/mit-krb5
		dev-libs/icu
		dev-libs/openssl"
BDEPEND="dev-dotnet/dotnetcore-sdk-bin
		sys-apps/yarn"

METAFILETOBUILD="MediaBrowser.sln"

pkg_setup() {
	enewgroup "${PN}"
	enewuser "${PN}" -1 -1 "/var/lib/${PN}" "${PN}"
	esethome "${PN}" "/var/lib/${PN}"

}

src_compile() {
	cd ${WORKDIR}/${PN}-web-${PV}
	yarn install
	cp -r dist/. ${S}/MediaBrowser.WebDashboard/jellyfin-web
	cd ${S}
	export DOTNET_CLI_TELEMETRY_OPTOUT=1
	dotnet build --configuration Release Jellyfin.Server
#	dotnet publish --configuration Release Jellyfin.Server --output ${S}/bin
	dotnet publish --configuration Release Jellyfin.Server --output ${S}/bin --self-contained --runtime linux-x64
}

src_install() {

	insinto /etc/${PN}
	doins ${FILESDIR}/logging.json
	fowners -R "${PN}:${PN}" "/etc/${PN}"

	cp "${FILESDIR}/${PN}.conf.d" "${T}/${PN}.conf.d" || die
	cp "${FILESDIR}/${PN}.service.conf" "${T}/${PN}.service.conf" || die

	sed -i "s|/usr/lib/|/usr/$(get_libdir)/|g" \
		"${T}/${PN}.conf.d" \
		"${T}/${PN}.service.conf" || die

	newconfd "${T}/${PN}.conf.d" "${PN}"
	newinitd "${FILESDIR}/${PN}.init.d" "${PN}"

	systemd_install_serviced ${T}/${PN}.service.conf
	systemd_dounit ${FILESDIR}/${PN}.service

	keepdir "/var/lib/${PN}"
	fowners -R "${PN}:${PN}" "/var/lib/${PN}"

	keepdir "/var/log/${PN}"
	fowners -R "${PN}:${PN}" "/var/log/${PN}"

	keepdir "/var/cache/${PN}"
	fowners -R "${PN}:${PN}" "/var/cache/${PN}"


	exeinto /usr/$(get_libdir)/${PN}
	doexe ${FILESDIR}/restart.sh

	insinto /usr/$(get_libdir)/${PN}/
	doins -r ${S}/bin
	fperms 0755 /usr/$(get_libdir)/${PN}/bin/${PN}

	dosym /usr/$(get_libdir)/${PN}/bin/${PN} /usr/bin/${PN}
}