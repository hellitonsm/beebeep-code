//////////////////////////////////////////////////////////////////////
//
// BeeBEEP Copyright (C) 2010-2023 Marco Mastroddi
//
// BeeBEEP is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// BeeBEEP is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with BeeBEEP. If not, see <http://www.gnu.org/licenses/>.
//
// Author: Marco Mastroddi <marco.mastroddi(AT)gmail.com>
//
// $Id: Screenshot.cpp 1562 2023-03-20 16:17:34Z mastroddi $
//
//////////////////////////////////////////////////////////////////////

#include "BeeApplication.h"
#include "Screenshot.h"
#include "IconManager.h"


Screenshot::Screenshot( QObject* parent )
 : QObject( parent ), m_pixmap()
{
  setObjectName( "Screenshot" );
}

bool Screenshot::grabWidget( QWidget* w )
{
  reset();
  if( !w )
    return false;
  const QWindow *window = w->windowHandle();
  if( window )
    m_pixmap = window->screen()->grabWindow( w->winId() );
  checkPixelRatio();
  return isValid();
}

void Screenshot::grabPrimaryScreen()
{
  reset();
  QScreen* primary_screen = QApplication::primaryScreen();
  if( primary_screen )
  {
    m_pixmap = primary_screen->grabWindow( 0 );
    QWidget w;
    QPixmap cursor_pix = IconManager::instance().icon( "cursor.png" ).pixmap( 32, 32 );
    QPainter p( &m_pixmap );
    p.drawPixmap( w.cursor().pos( primary_screen ), cursor_pix );
    checkPixelRatio();
  }
}

void Screenshot::checkPixelRatio()
{
  if( isValid() )
  {
    qreal device_pixel_ratio = beeApp->devicePixelRatio();
    if( device_pixel_ratio > 1.0 )
    {
      m_pixmap.setDevicePixelRatio( device_pixel_ratio );
      m_pixmap = m_pixmap.scaled( beeApp->primaryScreen()->geometry().width(), beeApp->primaryScreen()->geometry().height(), Qt::KeepAspectRatio );
    }
  }
}

bool Screenshot::save( const QString& file_name, const char* img_format, int img_quality )
{
  return m_pixmap.save( file_name, img_format, img_quality );
}
