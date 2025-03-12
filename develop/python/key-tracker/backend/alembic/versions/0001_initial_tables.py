"""initial_tables

Revision ID: 0001
Revises: 
Create Date: 2025-03-09

"""
from alembic import op
import sqlalchemy as sa
from datetime import datetime


# revision identifiers, used by Alembic.
revision = '0001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Створення таблиці sites
    op.create_table('sites',
        sa.Column('site_id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('site_code', sa.String(), nullable=False),
        sa.Column('address', sa.Text(), nullable=False),
        sa.Column('memo', sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint('site_id'),
        sa.UniqueConstraint('site_code')
    )

    # Створення таблиці keys
    op.create_table('keys',
        sa.Column('key_id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('site_code', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('key_count', sa.Integer(), nullable=False),
        sa.Column('set_count', sa.Integer(), nullable=False),
        sa.Column('is_issued', sa.Boolean(), default=False, nullable=True),
        sa.Column('memo', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['site_code'], ['sites.site_code'], ),
        sa.PrimaryKeyConstraint('key_id')
    )

    # Створення таблиці history
    op.create_table('history',
        sa.Column('history_id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('key_id', sa.Integer(), nullable=False),
        sa.Column('issued_to', sa.String(), nullable=True),
        sa.Column('issued_at', sa.TIMESTAMP(), default=datetime.utcnow, nullable=True),
        sa.Column('returned_at', sa.TIMESTAMP(), nullable=True),
        sa.Column('memo', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['key_id'], ['keys.key_id'], ),
        sa.PrimaryKeyConstraint('history_id')
    )


def downgrade() -> None:
    # Видалення таблиць у зворотному порядку
    op.drop_table('history')
    op.drop_table('keys')
    op.drop_table('sites')

